from fastapi import FastAPI, UploadFile, File
from fastapi.responses import JSONResponse
import torch

# Fix PyTorch 2.6 weights_only issue
import omegaconf
torch.serialization.add_safe_globals([omegaconf.listconfig.ListConfig, omegaconf.dictconfig.DictConfig])

import whisperx
import tempfile
import os
import gc

app = FastAPI(title="WhisperX API Server")

device = "cuda" if torch.cuda.is_available() else "cpu"
compute_type = "float16" if device == "cuda" else "int8"
model = None
model_a = None
metadata = None

@app.on_event("startup")
async def load_models():
    global model, model_a, metadata
    print(f"Loading WhisperX on {device}...")
    model = whisperx.load_model("large-v2", device, compute_type=compute_type)
    model_a, metadata = whisperx.load_align_model(language_code="en", device=device)
    print("Models loaded!")

@app.get("/health")
async def health():
    return {"status": "ok", "device": device}

@app.post("/transcribe")
async def transcribe(file: UploadFile = File(...)):
    global model, model_a, metadata
    
    with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp:
        tmp.write(await file.read())
        tmp_path = tmp.name
    
    try:
        audio = whisperx.load_audio(tmp_path)
        result = model.transcribe(audio, batch_size=16, language="en")
        result = whisperx.align(result["segments"], model_a, metadata, audio, device)
        
        words = []
        for seg in result["segments"]:
            for w in seg.get("words", []):
                words.append({
                    "word": w.get("word", ""),
                    "start": round(w.get("start", 0), 3),
                    "end": round(w.get("end", 0), 3)
                })
        
        return {"text": " ".join([w["word"].strip() for w in words]), "words": words}
    finally:
        os.unlink(tmp_path)
        gc.collect()
        if device == "cuda":
            torch.cuda.empty_cache()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8005)