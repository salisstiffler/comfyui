@echo off
:: 1. 检查 Ollama 服务是否已在运行
tasklist /fi "imagename eq ollama.exe" | findstr /i "ollama.exe" > nul
if %errorlevel% neq 0 (
    echo Starting Ollama Service...
    start "" "ollama" serve
    :: 等待 5 秒确保服务启动完毕
    timeout /t 5 /nobreak > nul
)

:: 2. 预加载模型 (运行一个空指令即退出，目的是加载模型到内存)
echo Loading model qwen3.5:9b...
ollama run qwen3.5:9b ""
exit
