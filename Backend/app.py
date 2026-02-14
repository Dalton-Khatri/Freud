from fastapi import FastAPI
from pydantic import BaseModel
import torch
from transformers import AutoTokenizer, AutoModelForCausalLM
import re
import os

app = FastAPI()

MODEL_NAME = "Dalton-Khatri/freud-mental-health-assistant"
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

print(f" Loading model: {MODEL_NAME}")
print(f" Device: {DEVICE}")

try:
    print("Step 1: Loading tokenizer...")
    
    try:
        tokenizer = AutoTokenizer.from_pretrained(
            MODEL_NAME,
            use_fast=False, 
            trust_remote_code=True
        )
        print(" Loaded slow tokenizer successfully")
    except Exception as e:
        print(f" Slow tokenizer failed: {e}")
        print("Trying fast tokenizer...")
        
        tokenizer = AutoTokenizer.from_pretrained(
            MODEL_NAME,
            use_fast=True,
            trust_remote_code=True
        )
        print(" Loaded fast tokenizer successfully")
    
    # Set pad token
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token
        print(" Set pad_token = eos_token")
    
    print("\nStep 2: Loading model...")
    model = AutoModelForCausalLM.from_pretrained(
        MODEL_NAME,
        torch_dtype=torch.float16 if DEVICE == "cuda" else torch.float32,
        low_cpu_mem_usage=True,
        trust_remote_code=True
    )
    
    model.to(DEVICE)
    model.eval()
    
    print(" Model loaded successfully!")
    print(f" Model parameters: {sum(p.numel() for p in model.parameters()):,}")
    
except Exception as e:
    print(f" CRITICAL ERROR loading model: {e}")
    print("\n TROUBLESHOOTING:")
    print("1. Check if model exists on HuggingFace")
    print("2. Verify model files are not corrupted")
    print("3. Try re-uploading the model")
    raise

class GenerateRequest(BaseModel):
    prompt: str
    max_tokens: int = 150
    temperature: float = 0.7

class GenerateResponse(BaseModel):
    response: str
    model_used: str = MODEL_NAME
    device: str = DEVICE

def clean_response(text: str, original_prompt: str = "") -> str:
    """
    Enhanced response cleaning to remove ALL tags and artifacts
    Based on testing notebook findings
    """
    
    # Step 1: Remove the original prompt
    if original_prompt:
        text = text.replace(original_prompt, "").strip()
    
    # Step 2: Remove system messages completely
    text = re.sub(r'<\|system\|>:.*?(?=<\|user\|>:|<\|assistant\|>:|$)', '', text, flags=re.DOTALL)
    
    # Step 3: Extract ONLY the first assistant response
    if "<|assistant|>:" in text:
        parts = text.split("<|assistant|>:")
        if len(parts) > 1:
            text = parts[1].strip()
        else:
            text = text.strip()
    
    # Step 4: CRITICAL - Stop at ANY user tag (catches all variants)
    # Patterns: <|user|>, <^user|>, <user>, etc.
    for pattern in [
        r'<\|user\|>',      # Standard format
        r'<\^user\|>',      # Variant seen in testing
        r'<user>',          # Alternative format
        r'\n<\|',           # Any new tag starting
        r'<\|user',         # Incomplete tag
    ]:
        if re.search(pattern, text, re.IGNORECASE):
            text = re.split(pattern, text, maxsplit=1)[0].strip()
    
    # Step 5: Remove ALL special tokens and formatting
    # Remove emotion tags
    text = re.sub(r'\[emotion:\s*\w+\]', '', text, flags=re.IGNORECASE)
    
    # Remove all pipe-based tags (|user|, |assistant|, |system|)
    text = re.sub(r'<\|.*?\|>:?', '', text)
    text = re.sub(r'<\^.*?\|>:?', '', text)
    text = re.sub(r'\*\|[a-z0-9]+\|', '', text)
    
    # Remove HTML/XML tags
    text = re.sub(r'</?[a-zA-Z][^>]*>', '', text)
    
    # Remove role labels that might appear
    text = re.sub(r'^(User:|Assistant:|Human:|AI:|System:|Freud:)\s*', '', text, flags=re.MULTILINE)
    
    # Step 6: Clean up excessive punctuation and symbols
    text = re.sub(r'[<>]{2,}', '', text)      # Remove << >> patterns
    text = re.sub(r'[#*]{3,}', '', text)      # Remove ### *** patterns  
    text = re.sub(r'!{4,}', '!', text)        # Multiple exclamations
    
    # Step 7: Clean whitespace
    text = re.sub(r'\s+', ' ', text).strip()
    text = re.sub(r'\n+', '\n', text).strip()
    
    # Step 8: Limit to reasonable length (prevent rambling)
    # Take only first 2-3 sentences for concise responses
    sentences = re.split(r'[.!?]+\s+', text)
    sentences = [s.strip() for s in sentences if s.strip()]
    
    if len(sentences) > 3:
        text = '. '.join(sentences[:3])
        if not text.endswith('.'):
            text += '.'
    
    return text.strip()

def is_valid_response(response: str) -> bool:
    """
    Enhanced validation based on testing notebook quality checks
    """
    if not response or len(response.strip()) < 10:
        return False
    
    if response.lower().startswith('error'):
        return False
    
    # Check for tag leakage (main issue from testing)
    if re.search(r'<\|.*?\|>', response):           # Standard tags
        return False
    if re.search(r'<\^.*?\|>', response):           # Variant tags
        return False
    if re.search(r'\[emotion:', response):          # Emotion tags
        return False
    if re.search(r'\*\|[a-z]+\d*\|', response):    # User/assistant markers
        return False
    
    # Check for other garbage patterns
    if re.search(r'<[^>]{20,}>', response):        # Long HTML tags
        return False
    if re.search(r'[<>]{3,}', response):           # Multiple brackets
        return False
    if re.search(r'!{10,}', response):             # Excessive exclamations (from testing)
        return False
    if re.search(r'##+', response):                # Hash patterns
        return False
    
    # Check for unwanted characters
    if re.search(r'[\u3000-\u303F\u3040-\u309F\u30A0-\u30FF]+', response):  # Japanese
        return False
    
    # Basic sanity checks
    word_count = len(response.split())
    if word_count < 3:
        return False
    
    # Check if response is just repeated punctuation
    if len(set(response.replace(' ', ''))) < 5:
        return False
    
    return True

def get_fallback_response() -> str:
    """Safe fallback when generation fails"""
    return "I'm here to listen and support you. Could you tell me more about what's on your mind?"

@app.get("/")
def read_root():
    """Health check"""
    return {
        "status": "Freud AI is running",
        "model": MODEL_NAME,
        "device": DEVICE,
        "version": "3.0 (Enhanced Cleaning)",
        "tokenizer_type": type(tokenizer).__name__
    }

@app.get("/health")
def health_check():
    """Detailed health check"""
    return {
        "status": "healthy",
        "model_loaded": model is not None,
        "tokenizer_loaded": tokenizer is not None,
        "device": DEVICE,
        "cuda_available": torch.cuda.is_available(),
        "model_parameters": sum(p.numel() for p in model.parameters())
    }

@app.post("/generate", response_model=GenerateResponse)
def generate(request: GenerateRequest):
    """
    Main generation endpoint
    Enhanced based on testing notebook findings
    """
    
    try:
        print(f"\n{'='*60}")
        print(f" New Request")
        print(f" Prompt length: {len(request.prompt)} chars")
        
        # Tokenize
        inputs = tokenizer(
            request.prompt,
            return_tensors="pt",
            truncation=True,
            max_length=512,
            padding=False
        ).to(DEVICE)
        
        print(f" Tokenization complete: {inputs.input_ids.shape}")
        
        # Generate with parameters matching successful testing notebook
        with torch.no_grad():
            outputs = model.generate(
                inputs.input_ids,
                max_new_tokens=request.max_tokens,
                temperature=request.temperature,
                top_p=0.9,
                top_k=50,
                do_sample=True,  # CRITICAL: Must be True for quality responses
                pad_token_id=tokenizer.pad_token_id,
                eos_token_id=tokenizer.eos_token_id,
                repetition_penalty=1.2,  # Matches testing notebook (was 1.3)
                no_repeat_ngram_size=3,
                early_stopping=True
            )
        
        print(f" Generation complete")
        
        # Decode
        full_response = tokenizer.decode(outputs[0], skip_special_tokens=True)
        print(f" Raw output length: {len(full_response)} chars")
        
        # Clean with enhanced cleaning
        cleaned_response = clean_response(full_response, request.prompt)
        print(f" Cleaned output length: {len(cleaned_response)} chars")
        
        # Validate with enhanced checks
        if not is_valid_response(cleaned_response):
            print(f" Quality check failed!")
            print(f"   Reason: Response validation failed")
            print(f"   Using fallback response")
            cleaned_response = get_fallback_response()
        else:
            print(f" Quality check passed")
        
        print(f" Returning response")
        
        return GenerateResponse(
            response=cleaned_response,
            model_used=MODEL_NAME,
            device=DEVICE
        )
        
    except torch.cuda.OutOfMemoryError:
        print(f" CUDA Out of Memory")
        return GenerateResponse(
            response="I'm experiencing high load. Please try again in a moment.",
            model_used=MODEL_NAME,
            device=DEVICE
        )
        
    except Exception as e:
        print(f" Error: {str(e)}")
        return GenerateResponse(
            response=get_fallback_response(),
            model_used=MODEL_NAME,
            device=DEVICE
        )

@app.post("/test")
def test_generation(request: GenerateRequest):
    """
    Debug endpoint - returns both raw and cleaned output
    Useful for verifying cleaning logic
    """
    try:
        inputs = tokenizer(
            request.prompt, 
            return_tensors="pt", 
            truncation=True, 
            max_length=512
        ).to(DEVICE)
        
        with torch.no_grad():
            outputs = model.generate(
                inputs.input_ids,
                max_new_tokens=request.max_tokens,
                temperature=request.temperature,
                top_p=0.9,
                top_k=50,
                do_sample=True,
                repetition_penalty=1.2,
                no_repeat_ngram_size=3,
            )
        
        raw = tokenizer.decode(outputs[0], skip_special_tokens=True)
        cleaned = clean_response(raw, request.prompt)
        is_valid = is_valid_response(cleaned)
        
        # Detailed validation breakdown
        validation_details = {
            "has_pipe_tags": bool(re.search(r'<\|.*?\|>', cleaned)),
            "has_caret_tags": bool(re.search(r'<\^.*?\|>', cleaned)),
            "has_emotion_tags": bool(re.search(r'\[emotion:', cleaned)),
            "has_excessive_exclamation": bool(re.search(r'!{10,}', cleaned)),
            "word_count": len(cleaned.split()),
            "char_count": len(cleaned)
        }
        
        return {
            "raw_output": raw,
            "cleaned_output": cleaned,
            "is_valid": is_valid,
            "validation_details": validation_details,
            "raw_length": len(raw),
            "cleaned_length": len(cleaned)
        }
    except Exception as e:
        return {"error": str(e)}

@app.get("/model-info")
def model_info():
    """Model information endpoint"""
    return {
        "model_name": MODEL_NAME,
        "device": DEVICE,
        "tokenizer_type": type(tokenizer).__name__,
        "vocab_size": len(tokenizer),
        "model_parameters": sum(p.numel() for p in model.parameters()),
        "pad_token": tokenizer.pad_token,
        "eos_token": tokenizer.eos_token,
        "version": "3.0"
    }

if __name__ == "__main__":
    import uvicorn
    
    port = int(os.environ.get("PORT", 7860))
    
    print(f" Starting Freud AI Backend")
    print(f" Port: {port}")
    print(f" Model: {MODEL_NAME}")
    print(f" Device: {DEVICE}")
    print(f" Version: 3.0 (Enhanced Cleaning)")
    print(f" Ready to receive requests!\n")
    
    uvicorn.run(app, host="0.0.0.0", port=port, log_level="info")
