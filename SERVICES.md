# Windows Background Services Setup

Run Chatterbox TTS and WhisperX as silent Windows background services that auto-start on boot.

## Quick Start

### Prerequisites
1. Run `setup.bat` first to install Python dependencies
2. Ensure both virtual environments exist:
   - `venv\` (for Chatterbox TTS)
   - `whisperx-server\venv\` (for WhisperX)

### Install Services

1. **Right-click** `install-as-service.bat`
2. Select **"Run as administrator"**
3. Wait for installation and auto-start to complete

That's it! Both services will now:
- Run silently in the background (no CMD windows)
- Auto-start when Windows boots
- Auto-restart if they crash

## Service Details

| Service | Port | Description |
|---------|------|-------------|
| ChatterboxTTS | 8004 | Text-to-Speech server |
| WhisperXServer | 8005 | Audio transcription server |

## Management

### Check Status
```
service-status.bat
```
Or double-click it - no admin required.

### Using PowerShell (Admin required for Start/Stop/Restart)
```powershell
# Check status
.\services\manage-services.ps1 -Status

# Start services
.\services\manage-services.ps1 -Start

# Stop services
.\services\manage-services.ps1 -Stop

# Restart services
.\services\manage-services.ps1 -Restart

# Manage only one service
.\services\manage-services.ps1 -Start -ChatterboxOnly
.\services\manage-services.ps1 -Stop -WhisperXOnly
```

### Using Windows Services GUI
1. Press `Win + R`
2. Type `services.msc`
3. Find **ChatterboxTTS** or **WhisperXServer**
4. Right-click to Start/Stop/Restart

## Uninstall Services

1. **Right-click** `uninstall-services.bat`
2. Select **"Run as administrator"**

Or via PowerShell:
```powershell
.\services\install-services.ps1 -Uninstall
```

## Logs

Service logs are stored in the `logs\` folder:

| Log File | Description |
|----------|-------------|
| `ChatterboxTTS-stdout.log` | Chatterbox standard output |
| `ChatterboxTTS-stderr.log` | Chatterbox errors and warnings |
| `WhisperXServer-stdout.log` | WhisperX standard output |
| `WhisperXServer-stderr.log` | WhisperX errors and warnings |
| `tts_server.log` | Application-level TTS logs |

Logs auto-rotate at 10MB.

## Endpoints

Once running, access the services at:

- **Chatterbox TTS**: http://localhost:8004
  - Web UI: http://localhost:8004/
  - API Docs: http://localhost:8004/docs

- **WhisperX**: http://localhost:8005
  - Health Check: http://localhost:8005/health
  - Transcribe: POST http://localhost:8005/transcribe

## Troubleshooting

### Services won't start
1. Check logs in `logs\` folder for errors
2. Ensure virtual environments exist (`venv\` and `whisperx-server\venv\`)
3. Run `setup.bat` if dependencies are missing

### First startup is slow
Normal - models are downloaded on first run:
- Chatterbox downloads ~2GB model from HuggingFace
- WhisperX downloads ~3GB model

### Port already in use
1. Stop the existing process using the port
2. Or change port in `config.yaml` (for Chatterbox)

### Check if services are responding
```cmd
curl http://localhost:8004/docs
curl http://localhost:8005/health
```

## Technical Details

- Uses [NSSM](https://nssm.cc/) (Non-Sucking Service Manager) to wrap Python scripts
- NSSM is auto-downloaded on first install
- Services run as LocalSystem account
- Configured for automatic restart on failure (5 second delay)

## File Structure

```
├── install-as-service.bat    # Install services (run as admin)
├── uninstall-services.bat    # Remove services (run as admin)
├── service-status.bat        # Check status (no admin needed)
├── services/
│   ├── install-services.ps1  # Main installer script
│   ├── manage-services.ps1   # Service management script
│   └── nssm.exe              # Auto-downloaded service manager
└── logs/
    ├── ChatterboxTTS-stdout.log
    ├── ChatterboxTTS-stderr.log
    ├── WhisperXServer-stdout.log
    └── WhisperXServer-stderr.log
```
