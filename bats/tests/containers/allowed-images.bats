load '../helpers/load'
RD_USE_IMAGE_ALLOW_LIST=true
BASE_IMAGE="large-image"
IMAGE1="image1"
IMAGE2="image2"
IMAGE3="image3"
IMAGE4="image4"

log(){
    echo "--------------------"
    "$@"
    echo "--------------------"
}

get_registry_addr() {
    # Using ifconfig should be supported on all platforms, since we're running BATS in a WSL distribution on Windows.
    #IP=$(ifconfig | grep -v '127.0.0.1' | grep 'inet ' | awk '{print $2}' | head -n 1)
    IP="10.0.0.3"
    REGISTRY_ADDR="$IP":4000
    log echo "Registry address is: $REGISTRY_ADDR"
}

generate_certs_for_local_registry() {
    #WORK_DIR="$BATS_FILE_TMPDIR/allowed_images_list_test"
    WORK_DIR="$PWD/allowed_images_list_test"
    CRT_PATH="$WORK_DIR/certs"
    mkdir -p "$CRT_PATH"
    ctrctl pull --quiet alpine/mkcert
    ctrctl run -v "$CRT_PATH":/root/.local/share/mkcert alpine/mkcert:latest -install
    log ls "$CRT_PATH"
    ctrctl run -v "$CRT_PATH":/root/.local/share/mkcert \
        alpine/mkcert:latest \
        -cert-file /root/.local/share/mkcert/registry.crt \
        -key-file /root/.local/share/mkcert/registry.key \
        $IP 10.0.0.254 localhost 127.0.0.1 ::1
    log ls "$CRT_PATH"
    ##TODO: delete this
    mkdir -p "$HOME/.docker/certs.d/$REGISTRY_ADDR"
    cp "$CRT_PATH/rootCA.pem" "$HOME/.docker/certs.d/$REGISTRY_ADDR/ca.crt"
    log cat "$HOME/.docker/certs.d/$REGISTRY_ADDR/ca.crt"
}

run_private_local_registry() {
    ctrctl network create --subnet 10.0.0.0/24 --gateway 10.0.0.254 bats
    log echo "$IP"
    ctrctl run -d \
        --net bats \
        --ip 10.0.0.3 \
        --name registry \
        --restart=always \
        -v "$CRT_PATH":/certs \
        -e REGISTRY_HTTP_ADDR=0.0.0.0:4000 \
        -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt \
        -e REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
        -p 4000:4000 \
        registry:2
    log ctrctl ps -a
}

####### UPDATED the daemon.json in the rdctl shell
######docker context update rancher-desktop --docker "skip-tls-verify=true"

build_images() {
    cat >"${WORK_DIR}/Dockerfile" <<'EOF'
FROM ubuntu:20.04
WORKDIR /app
# This produces image over 1GB
RUN dd if=/dev/urandom of=/largefile.test bs=10M count=100
EOF
    cd "$WORK_DIR"
    run ctrctl build -t "$BASE_IMAGE" .
    assert_success
}

push_images_to_local_registry() {
    local image_name="$1"
    log echo $REGISTRY_ADDR
    local repository="$REGISTRY_ADDR/$image_name"
    ctrctl tag "$BASE_IMAGE" "$repository"
    log echo $repository
    ctrctl push "$repository"
    assert_success
    #ctrctl rmi -f "$repository"
}

@test 'start' {
    factory_reset
    start_kubernetes
    wait_for_container_engine
    wait_for_kubelet
    get_registry_addr
    generate_certs_for_local_registry
    rdctl shutdown
    rdctl start
    wait_for_container_engine
    wait_for_kubelet
    run_private_local_registry
    build_images
    push_images_to_local_registry "$IMAGE1"
   # push_images_to_local_registry "$IMAGE2"
   # push_images_to_local_registry "$IMAGE3"
   # push_images_to_local_registry "$IMAGE4"
    assert_success
}
#
#@test 'update the list of patterns first time' {
#    update_allowed_patterns true "$IMAGE1" "$IMAGE2" "$IMAGE3"
#}
#
#@test 'verify pull $IMAGE1 succeeds' {
#    ctrctl pull  "$REGISTRY_ADDR/$IMAGE1"
#}
#
#@test 'verify pull $IMAGE2 succeeds' {
#    ctrctl pull  "$REGISTRY_ADDR/$IMAGE2"
#}
#
#@test 'verify pull $IMAGE3 succeeds' {
#    ctrctl pull "$REGISTRY_ADDR/$IMAGE3"
#}
#
#@test 'verify pull $IMAGE4 fails' {
#    run ctrctl pull "$REGISTRY_ADDR/$IMAGE4"
#    assert_failure
#}
#
#@test 'drop $IMAGE3 from the allowed-image list, add $IMAGE4' {
#    update_allowed_patterns true "$IMAGE1" "$IMAGE2" "$IMAGE4"
#}

##@test 'clear images' {
##    for image in IMAGE_NGINX IMAGE_BUSYBOX IMAGE_PYTHON; do
##        ctrctl rmi "${!image}"
##    done
##}
##
##@test 'verify pull python fails' {
##    run ctrctl pull --quiet "$IMAGE_PYTHON"
##    assert_failure
##}
##
##@test 'verify pull ruby succeeds' {
##    ctrctl pull --quiet "$IMAGE_RUBY"
##}
##
##@test 'clear all patterns' {
##    update_allowed_patterns true
##}
##
##@test 'can run kubectl' {
##    kubectl run nginx --image="${IMAGE_NGINX}:latest" --port=8080
##}
##
##verify_no_nginx() {
##    run kubectl get pods
##    assert_success
##    assert_output --partial "ImagePullBackOff"
##}
##
##@test 'but fails to stand up a pod for forbidden image' {
##    try --max 18 --delay 10 verify_no_nginx
##}
##
##@test 'set patterns with the allowed list disabled' {
##    update_allowed_patterns false "$IMAGE_NGINX" "$IMAGE_BUSYBOX" "$IMAGE_RUBY"
##}
##
##@test 'verify pull python succeeds because allowedImages filter is disabled' {
##    ctrctl pull --quiet "$IMAGE_PYTHON"
##}
