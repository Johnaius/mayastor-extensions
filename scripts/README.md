# Enabling TLS

1. Build components from [rest_tls][rest_tls] branch in control plane
    - ```./scripts/release.sh --registry <registry url> --alias-tag <tag> --image rest operators.diskpool agents.core```
1. set tls.enabled to true [here][enableTls]


[enableTls]: https://github.com/Johnaius/mayastor-extensions/blob/tls/chart/values.yaml#L94-L95
[rest_tls]: https://github.com/Johnaius/mayastor-control-plane/tree/rest_tls