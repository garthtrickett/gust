cargo run -- --test
cc gust_output.c -o gust_program && ./gust_program
cargo clippy --fix --allow-dirty
