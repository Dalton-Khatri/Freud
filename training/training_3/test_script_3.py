import torch
from transformers import AutoTokenizer, AutoModelForCausalLM


MODEL_PATH = "/kaggle/working/Freud/freud_model/final"
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

MAX_NEW_TOKENS = 120
TEMPERATURE = 0.7
TOP_P = 0.9

tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH)
model = AutoModelForCausalLM.from_pretrained(MODEL_PATH)
model.to(DEVICE)
model.eval()

def generate(prompt):
    inputs = tokenizer(prompt, return_tensors="pt").to(DEVICE)

    with torch.no_grad():
        output = model.generate(
            **inputs,
            max_new_tokens=MAX_NEW_TOKENS,
            do_sample=True,
            temperature=TEMPERATURE,
            top_p=TOP_P,
            eos_token_id=tokenizer.eos_token_id,
            pad_token_id=tokenizer.eos_token_id
        )

    return tokenizer.decode(output[0], skip_special_tokens=True)

tests = [
    {
        "name": "Sadness (emotion tag)",
        "prompt": """
<|system|>: You are Freud, a calm, empathetic therapeutic AI assistant.
<|user|>:
[emotion: sad]
I feel very lonely these days
<|assistant|>:
"""
    },
    {
        "name": "Stress (emotion tag)",
        "prompt": """
<|system|>: You are Freud, a calm, empathetic therapeutic AI assistant.
<|user|>:
[emotion: stressed]
I feel overwhelmed with everything
<|assistant|>:
"""
    },
    {
        "name": "Multi-turn continuation",
        "prompt": """
<|system|>: You are Freud, a calm, empathetic therapeutic AI assistant.
<|user|>:
[emotion: sad]
I feel empty
<|assistant|>:
That sounds really heavy. I'm here with you.
<|user|>:
I don't know why I feel this way
<|assistant|>:
"""
    },
    {
        "name": "No emotion tag (generalization test)",
        "prompt": """
<|system|>: You are Freud, a calm, empathetic therapeutic AI assistant.
<|user|>:
I feel like crying for no reason
<|assistant|>:
"""
    }
]

for t in tests:
    print("=" * 80)
    print(f"TEST: {t['name']}")
    print("-" * 80)
    print(generate(t["prompt"]))
    print()
