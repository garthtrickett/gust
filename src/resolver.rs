use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};
use crate::typechecker::{TypeError, TypeErrorKind};
use crate::ast::Program;

pub trait FileSystem {
    fn read_file(&self, path: &Path) -> std::io::Result<String>;
    fn canonicalize(&self, path: &Path) -> std::io::Result<PathBuf>;
}

pub struct RealFileSystem;

impl FileSystem for RealFileSystem {
    fn read_file(&self, path: &Path) -> std::io::Result<String> {
        std::fs::read_to_string(path)
    }
    fn canonicalize(&self, path: &Path) -> std::io::Result<PathBuf> {
        std::fs::canonicalize(path)
    }
}

pub struct Module {
    pub path: PathBuf,
    pub program: Program,
    pub source: String,
    pub dependencies: Vec<Dependency>,
}

pub struct Dependency {
    pub path: PathBuf,
    pub alias: Option<String>,
    pub span: crate::token::Span,
}

pub struct ModuleResolver;

impl ModuleResolver {
    pub fn new() -> Self {
        ModuleResolver
    }

    pub fn resolve<FS: FileSystem>(
        &self,
        entry_path: &Path,
        fs: &FS,
    ) -> Result<(Vec<PathBuf>, HashMap<PathBuf, Module>), TypeError> {
        let mut visiting = HashSet::new();
        let mut visited = HashSet::new();
        let mut resolved_order = Vec::new();
        let mut modules = HashMap::new();

        let canonical_entry = fs.canonicalize(entry_path).map_err(|e| TypeError { 
            kind: TypeErrorKind::SyntaxError,
            message: format!("Failed to canonicalize entry path {:?}: {}", entry_path, e),
            span: None,
        })?;

        self.visit(
            canonical_entry,
            fs,
            &mut visiting,
            &mut visited,
            &mut resolved_order,
            &mut modules,
        )?;

        Ok((resolved_order, modules))
    }

    fn visit<FS: FileSystem>(
        &self,
        path: PathBuf,
        fs: &FS,
        visiting: &mut HashSet<PathBuf>,
        visited: &mut HashSet<PathBuf>,
        resolved_order: &mut Vec<PathBuf>,
        modules: &mut HashMap<PathBuf, Module>,
    ) -> Result<(), TypeError> {
        if visiting.contains(&path) {
            return Err(TypeError {
                kind: TypeErrorKind::SyntaxError,
                message: format!("Cyclic dependency detected: {:?}", path),
                span: None,
            });
        }

        if visited.contains(&path) {
            return Ok(());
        }

        visiting.insert(path.clone());

        // 1. Read and parse file
        let source = fs.read_file(&path).map_err(|e| TypeError {
            kind: TypeErrorKind::SyntaxError,
            message: format!("Failed to read file {:?}: {}", path, e),
            span: None,
        })?;

        let lexer = crate::lexer::Lexer::new(&source);
        let mut parser = crate::parser::Parser::new(lexer);
        let program = parser.parse_program();

        if !parser.errors.is_empty() {
            return Err(parser.errors[0].clone());
        }

        // 2. Extract dependencies
        let mut dependencies = Vec::new();
        let current_dir = path.parent().unwrap_or_else(|| Path::new(""));

        for stmt in &program.statements {
            if let crate::ast::Statement::Import { path: imp_path, alias, span } = stmt {
                let relative_path = Path::new(imp_path);
                let combined_path = current_dir.join(relative_path);
                let canonical_path = fs.canonicalize(&combined_path).map_err(|e| TypeError {
                    kind: TypeErrorKind::SyntaxError,
                    message: format!("Failed to resolve import {:?}: {}", imp_path, e),
                    span: Some(*span),
                })?;

                dependencies.push(Dependency {
                    path: canonical_path,
                    alias: alias.clone(),
                    span: *span,
                });
            }
        }

        // 3. Recurse on dependencies first (to output them first in topological order)
        for dep in &dependencies {
            self.visit(
                dep.path.clone(),
                fs,
                visiting,
                visited,
                resolved_order,
                modules,
            )?;
        }

        visiting.remove(&path);
        visited.insert(path.clone());
        resolved_order.push(path.clone());

        modules.insert(
            path.clone(),
            Module {
                path,
                program,
                source,
                dependencies,
            },
        );

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    pub struct MockFileSystem {
        files: HashMap<PathBuf, String>,
    }

    impl MockFileSystem {
        pub fn new() -> Self {
            MockFileSystem {
                files: HashMap::new(),
            }
        }

        pub fn add_file(&mut self, path: &str, content: &str) {
            self.files.insert(PathBuf::from(path), content.to_string());
        }
    }

    impl FileSystem for MockFileSystem {
        fn read_file(&self, path: &Path) -> std::io::Result<String> {
            if let Some(content) = self.files.get(path) {
                Ok(content.clone())
            } else {
                Err(std::io::Error::new(
                    std::io::ErrorKind::NotFound,
                    "File not found",
                ))
            }
        }

        fn canonicalize(&self, path: &Path) -> std::io::Result<PathBuf> {
            let mut components = Vec::new();
            for component in path.components() { 
                match component {
                    std::path::Component::ParentDir => { 
                        components.pop();
                    }
                    std::path::Component::CurDir => {}
                    _ => {
                        components.push(component);
                    }
                }
            }
            let normalized: PathBuf = components.into_iter().collect();
            Ok(normalized)
        }
    }

    #[test] 
    fn test_virtual_resolution() {
        let mut fs = MockFileSystem::new();
        fs.add_file("main.gst", "import \"lib.gst\"; func main() {}");
        fs.add_file("lib.gst", "import \"helper.gst\";");
        fs.add_file("helper.gst", "func helper() {}");

        let resolver = ModuleResolver::new();
        let res = resolver.resolve(Path::new("main.gst"), &fs);
        assert!(res.is_ok());
        let (order, _modules) = res.unwrap();

        assert_eq!(order.len(), 3);
        assert_eq!(order[0], PathBuf::from("helper.gst"));
        assert_eq!(order[1], PathBuf::from("lib.gst"));
        assert_eq!(order[2], PathBuf::from("main.gst"));
    }

    #[test]
    fn test_circular_dependency_detected() {
        let mut fs = MockFileSystem::new();
        fs.add_file("a.gst", "import \"b.gst\";");
        fs.add_file("b.gst", "import \"a.gst\";");

        let resolver = ModuleResolver::new();
        let res = resolver.resolve(Path::new("a.gst"), &fs);
        assert!(res.is_err());
        let err = res.unwrap_err();
        assert!(err.message.contains("Cyclic dependency detected"));
    }
}