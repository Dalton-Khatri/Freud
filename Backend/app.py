from fastapi import FastAPI
from pydantic import BaseModel
import torch
from transformers import AutoTokenizer, AutoModelForCausalLM
import re
import os
import random

app = FastAPI()

MODEL_NAME = "Dalton-Khatri/freud-mental-health-assistant"
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

print(f"Loading model: {MODEL_NAME}")
print(f"Device: {DEVICE}")

try:
    print("Step 1: Loading tokenizer...")
    
    try:
        tokenizer = AutoTokenizer.from_pretrained(
            MODEL_NAME,
            use_fast=False,
            trust_remote_code=True
        )
        print("Loaded slow tokenizer successfully")
    except Exception as e:
        print(f"Slow tokenizer failed: {e}")
        print("Trying fast tokenizer...")
        
        tokenizer = AutoTokenizer.from_pretrained(
            MODEL_NAME,
            use_fast=True,
            trust_remote_code=True
        )
        print("Loaded fast tokenizer successfully")
    
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token
        print("Set pad_token = eos_token")
    
    print("\nStep 2: Loading model...")
    model = AutoModelForCausalLM.from_pretrained(
        MODEL_NAME,
        torch_dtype=torch.float16 if DEVICE == "cuda" else torch.float32,
        low_cpu_mem_usage=True,
        trust_remote_code=True
    )
    
    model.to(DEVICE)
    model.eval()
    
    print("Model loaded successfully!")
    print(f"Model parameters: {sum(p.numel() for p in model.parameters()):,}")
    
except Exception as e:
    print(f"CRITICAL ERROR loading model: {e}")
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
    ULTRA-AGGRESSIVE cleaning to remove ALL tags and artifacts
    """
    
    # Step 1: Remove the original prompt
    if original_prompt:
        text = text.replace(original_prompt, "").strip()
    
    # Step 2: CRITICAL - Extract ONLY content after final <|assistant|>:
    if "<|assistant|>:" in text:
        parts = text.split("<|assistant|>:")
        if len(parts) > 1:
            text = parts[-1].strip()
    
    # Step 3: STOP at ANY indication of user tag
    stop_patterns = [
        r'<\|user\|>',
        r'<\^user\|>',
        r'<user>',
        r'<\/\|user\|>',
        r'\n<\|',
        r'<\|user',
        r'\[emotion:',
    ]
    
    for pattern in stop_patterns:
        if re.search(pattern, text, re.IGNORECASE):
            text = re.split(pattern, text, maxsplit=1)[0].strip()
            break
    
    # Step 4: Remove ALL special markers
    text = re.sub(r'\[emotion:\s*\w+\]', '', text, flags=re.IGNORECASE)
    text = re.sub(r'<\|[^>]*\|>:?', '', text)
    text = re.sub(r'<\^[^>]*\|>:?', '', text)
    text = re.sub(r'<\/\|[^>]*\|>:?', '', text)
    text = re.sub(r'\*\|[a-z0-9]+\|', '', text)
    text = re.sub(r'</?[a-zA-Z][^>]*>', '', text)
    text = re.sub(r'^(User:|Assistant:|Human:|AI:|System:|Freud:)\s*', '', text, flags=re.MULTILINE)
    text = re.sub(r'(User:|Assistant:|Human:|AI:|System:|Freud:)', '', text)
    
    # Step 5: Remove arrow annotations
    text = re.sub(r'←[^.!?]*[.!?]', '', text)
    text = re.sub(r'→[^.!?]*[.!?]', '', text)
    text = re.sub(r'<-[^.!?]*[.!?]', '', text)
    text = re.sub(r'->[^.!?]*[.!?]', '', text)
    
    # Step 6: Clean formatting artifacts
    text = re.sub(r'[<>]{2,}', '', text)
    text = re.sub(r'[#*]{3,}', '', text)
    text = re.sub(r'!{4,}', '!', text)
    text = re.sub(r'\*{2,}', '', text)
    
    # Step 7: Remove "Your Name:" artifacts
    text = re.sub(r'Your Name:\s*\w*', '', text, flags=re.IGNORECASE)
    text = re.sub(r'Name:\s*\w*', '', text)
    
    # Step 8: Clean whitespace
    text = re.sub(r'\s+', ' ', text).strip()
    text = re.sub(r'\n+', '\n', text).strip()
    
    # Step 9: Remove leading/trailing punctuation artifacts
    text = re.sub(r'^[.,;:!?\s]+', '', text)
    text = re.sub(r'[.,;:\s]+$', '', text)
    
    # Step 10: Limit to 2-3 sentences
    sentences = re.split(r'[.!?]+\s+', text)
    sentences = [s.strip() for s in sentences if s.strip() and len(s.strip()) > 3]
    
    if len(sentences) > 3:
        text = '. '.join(sentences[:3])
        if not text.endswith(('.', '!', '?')):
            text += '.'
    elif sentences:
        text = '. '.join(sentences)
        if not text.endswith(('.', '!', '?')):
            text += '.'
    
    return text.strip()

def is_valid_response(response: str) -> bool:
    """
    STRICT validation - reject anything suspicious
    """
    if not response or len(response.strip()) < 10:
        print(f"Too short: {len(response)} chars")
        return False
    
    tag_patterns = [
        r'<\|.*?\|>',
        r'<\^.*?\|>',
        r'</?user>',
        r'</?assistant>',
        r'</?system>',
        r'\[emotion:',
        r'\*\|[a-z]+\d*\|',
        r'←',
        r'→',
        r'Your Name:',
    ]
    
    for pattern in tag_patterns:
        if re.search(pattern, response, re.IGNORECASE):
            print(f"Tag leakage: Found {pattern}")
            return False
    
    if response.lower().startswith('error'):
        print(f"Error message")
        return False
    
    special_chars = len(re.findall(r'[^a-zA-Z0-9\s.,!?\'-]', response))
    if special_chars > len(response) * 0.2:
        print(f"Too many special characters: {special_chars}")
        return False
    
    if response.count('!') > 5 or response.count('?') > 3:
        print(f"Excessive punctuation")
        return False
    
    words = response.split()
    for i in range(len(words) - 3):
        if len(words) > i+3 and words[i] == words[i+1] == words[i+2] == words[i+3]:
            print(f"Repetition detected: {words[i]}")
            return False
    
    word_count = len(words)
    if word_count < 5:
        print(f"Too few words: {word_count}")
        return False
    
    if len(set(response.replace(' ', ''))) < 8:
        print(f"Not enough unique characters")
        return False
    
    return True

def get_fallback_response() -> str:
    """
    Safe, empathetic fallback when generation fails
    """
    fallbacks = [
        "I'm here to listen and support you. Could you tell me more about what's on your mind?",
        "I want to understand what you're going through. Can you share more about how you're feeling?",
        "Thank you for sharing that with me. I'm listening. What else would you like to talk about?",
        "I hear you. Would you like to explore these feelings together?",
        "I'm here for you. What's weighing on you right now?",
    ]
    
    return random.choice(fallbacks)

@app.get("/")
def read_root():
    """Health check"""
    return {
        "status": "Freud AI is running",
        "model": MODEL_NAME,
        "device": DEVICE,
        "version": "4.0 (Ultra-Clean)",
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
    Main generation endpoint with ULTRA-CLEAN response processing
    """
    
    try:
        print(f"\n{'='*60}")
        print(f"New Request")
        print(f"Prompt length: {len(request.prompt)} chars")
        
        inputs = tokenizer(
            request.prompt,
            return_tensors="pt",
            truncation=True,
            max_length=512,
            padding=False
        ).to(DEVICE)
        
        print(f"Tokenization complete: {inputs.input_ids.shape}")
        
        with torch.no_grad():
            outputs = model.generate(
                inputs.input_ids,
                max_new_tokens=request.max_tokens,
                temperature=request.temperature,
                top_p=0.9,
                top_k=50,
                do_sample=True,
                pad_token_id=tokenizer.pad_token_id,
                eos_token_id=tokenizer.eos_token_id,
                repetition_penalty=1.2,
                no_repeat_ngram_size=3,
                early_stopping=True
            )
        
        print(f"Generation complete")
        
        full_response = tokenizer.decode(outputs[0], skip_special_tokens=True)
        print(f"Raw output length: {len(full_response)} chars")
        print(f"Raw output preview: {full_response[:200]}...")
        
        cleaned_response = clean_response(full_response, request.prompt)
        print(f"Cleaned output length: {len(cleaned_response)} chars")
        print(f"Cleaned output: {cleaned_response}")
        
        if not is_valid_response(cleaned_response):
            print(f"Quality check failed!")
            print(f" Using fallback response")
            cleaned_response = get_fallback_response()
        else:
            print(f"Quality check passed")
        
        print(f"Returning response")
        
        return GenerateResponse(
            response=cleaned_response,
            model_used=MODEL_NAME,
            device=DEVICE
        )
        
    except torch.cuda.OutOfMemoryError:
        print(f"CUDA Out of Memory")
        return GenerateResponse(
            response="I'm experiencing high load. Please try again in a moment.",
            model_used=MODEL_NAME,
            device=DEVICE
        )
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return GenerateResponse(
            response=get_fallback_response(),
            model_used=MODEL_NAME,
            device=DEVICE
        )

if __name__ == "__main__":
    import uvicorn
    
    port = int(os.environ.get("PORT", 7860))
    
    print(f"Starting Freud AI Backend")
    print(f"Port: {port}")
    print(f"Model: {MODEL_NAME}")
    print(f"Device: {DEVICE}")
    
    uvicorn.run(app, host="0.0.0.0", port=port, log_level="info")