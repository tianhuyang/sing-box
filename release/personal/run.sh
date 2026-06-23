CONFIG=/Users/tianhuyang/Desktop/hugo/projects/virtual-router/virtual-router/server/config/config.json
sudo go run -tags "with_gvisor with_quic with_dhcp with_wireguard with_utls with_acme with_clash_api with_tailscale with_ccm with_ocm with_naive_outbound badlinkname tfogo_checklinkname0" -ldflags "-X internal/godebug.defaultGODEBUG=multipathtcp=0 -checklinkname=0" ./cmd/sing-box run -c $CONFIG
