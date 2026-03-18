@echo off
echo Starting Cloudflare Tunnel for ComfyUI...
:: Using http2 protocol to avoid QUIC handshake timeouts in some network environments
cloudflared tunnel --config server/cloudflared-config.yaml --protocol http2 run comfyui-tunnel
pause
