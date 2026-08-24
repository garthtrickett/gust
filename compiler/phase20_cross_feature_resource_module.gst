extern func phase20_cross_feature_resource_event(token: int) int;

#[linear]
#[destructor(destroy_cross_feature_resource)]
#[opaque]
type CrossFeatureResource struct {
    token: int
}

#[private]
func destroy_cross_feature_resource(resource: CrossFeatureResource) {
    unsafe {
        phase20_cross_feature_resource_event(resource.token);
    }
}

func acquire_cross_feature_resource(token: int) CrossFeatureResource {
    mut resource: CrossFeatureResource;
    resource.token = token;
    return resource;
}
