"""
FIXED Data Cleaner for Freud Model
===================================
This version fixes the critical issue where the model was learning to generate
both sides of the conversation.

Key Fix: Each training sample ends IMMEDIATELY after the assistant's response,
with NO newlines or additional user messages.
"""

import json
from pathlib import Path
import random
from sklearn.model_selection import train_test_split
from datasets import Dataset


def save_json(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


BASE_DIR = Path(__file__).resolve().parent
INPUT_FILE = BASE_DIR / "Dataset.json"

OUTPUT_DIR = BASE_DIR / "data_fixed"
OUTPUT_TRAIN_DIR = OUTPUT_DIR / "train"
OUTPUT_VAL_DIR = OUTPUT_DIR / "valid"

# Create directories
OUTPUT_DIR.mkdir(exist_ok=True)
OUTPUT_TRAIN_DIR.mkdir(exist_ok=True)
OUTPUT_VAL_DIR.mkdir(exist_ok=True)

VALID_SPLIT = 0.1
RANDOM_SEED = 42

SYSTEM_PROMPT = (
    "You are Freud, a calm, empathetic therapeutic AI assistant. "
    "You respond thoughtfully, kindly, and supportively. "
    "You ask gentle follow-up questions and never judge the user. "
    "Keep your responses concise (2-3 sentences) and avoid repetition."
)

random.seed(RANDOM_SEED)

# Load dataset
print("Loading dataset...")
with open(INPUT_FILE, "r", encoding="utf-8") as f:
    dataset = json.load(f)

intents = dataset["intents"]
samples = []

def create_single_turn_sample(emotion, user_message, assistant_response):
    """
    Creates a properly formatted single-turn training sample.
    CRITICAL: Ends immediately after assistant response with NO trailing newline.
    """
    return (
        f"<|system|>: {SYSTEM_PROMPT}\n"
        f"<|user|>:\n"
        f"[emotion: {emotion}]\n"
        f"{user_message.strip()}\n"
        f"<|assistant|>:\n"
        f"{assistant_response.strip()}"  # NO newline here!
    )


def create_multi_turn_sample(emotion, turns, max_context=2):
    """
    Creates a multi-turn sample with context from previous exchanges.
    CRITICAL: Still only trains on ONE assistant response at the end.
    
    Args:
        emotion: Emotion tag for all turns
        turns: List of (user, assistant) tuples
        max_context: Maximum previous turns to include as context
    """
    # Build prompt with system message
    prompt = f"<|system|>: {SYSTEM_PROMPT}\n"
    
    # Add context turns (all complete exchanges)
    context_turns = turns[:-1][-max_context:] if len(turns) > 1 else []
    for user_msg, asst_msg in context_turns:
        prompt += f"<|user|>:\n[emotion: {emotion}]\n{user_msg.strip()}\n"
        prompt += f"<|assistant|>:\n{asst_msg.strip()}\n"
    
    # Add final turn (the one we're training on)
    final_user, final_assistant = turns[-1]
    prompt += f"<|user|>:\n[emotion: {emotion}]\n{final_user.strip()}\n"
    prompt += f"<|assistant|>:\n{final_assistant.strip()}"  # NO newline!
    
    return prompt


print("\nProcessing intents...")
total_intents = len(intents)

for idx, intent in enumerate(intents):
    if (idx + 1) % 10 == 0:
        print(f"Processing intent {idx + 1}/{total_intents}...")
    
    emotion = intent.get("tag", "neutral")
    patterns = intent.get("patterns", [])
    responses = intent.get("responses", [])

    if not patterns or not responses:
        continue

    # Create single-turn samples (one for each pattern)
    for pattern in patterns:
        response = random.choice(responses)
        sample_text = create_single_turn_sample(emotion, pattern, response)
        samples.append({"text": sample_text})

    # Create multi-turn samples if we have enough patterns
    if len(patterns) >= 3:
        # Create 2-turn conversations
        for i in range(len(patterns) - 1):
            turns = [
                (patterns[i], random.choice(responses)),
                (patterns[i + 1], random.choice(responses))
            ]
            sample_text = create_multi_turn_sample(emotion, turns, max_context=1)
            samples.append({"text": sample_text})
        
        # Create some 3-turn conversations
        if len(patterns) >= 4:
            for i in range(0, len(patterns) - 2, 2):  # Every other one to avoid too many
                turns = [
                    (patterns[i], random.choice(responses)),
                    (patterns[i + 1], random.choice(responses)),
                    (patterns[i + 2], random.choice(responses))
                ]
                sample_text = create_multi_turn_sample(emotion, turns, max_context=2)
                samples.append({"text": sample_text})


print(f"\nTotal samples created: {len(samples)}")

# Shuffle
random.shuffle(samples)

# Save all preprocessed data
all_data_file = OUTPUT_DIR / "all_preprocessed.json"
save_json(all_data_file, samples)
print(f"Saved all data to: {all_data_file}")

# Split into train and validation
train_data, val_data = train_test_split(
    samples,
    test_size=VALID_SPLIT,
    random_state=RANDOM_SEED
)

# Save JSON versions
train_json_file = OUTPUT_DIR / "train.json"
val_json_file = OUTPUT_DIR / "valid.json"
save_json(train_json_file, train_data)
save_json(val_json_file, val_data)
print(f"Saved train data to: {train_json_file}")
print(f"Saved validation data to: {val_json_file}")

# Create Arrow datasets
train_dataset = Dataset.from_list(train_data)
val_dataset = Dataset.from_list(val_data)

# Save to disk
train_dataset.save_to_disk(OUTPUT_TRAIN_DIR)
val_dataset.save_to_disk(OUTPUT_VAL_DIR)
print(f"Saved train Arrow dataset to: {OUTPUT_TRAIN_DIR}")
print(f"Saved validation Arrow dataset to: {OUTPUT_VAL_DIR}")

# Print statistics
print("\n" + "="*60)
print("DATASET STATISTICS")
print(f"Total samples: {len(samples)}")
print(f"Training samples: {len(train_dataset)}")
print(f"Validation samples: {len(val_dataset)}")
print(f"Train/Val split: {len(train_data)/(len(train_data)+len(val_data))*100:.1f}% / {len(val_data)/(len(train_data)+len(val_data))*100:.1f}%")

# Show sample
print("SAMPLE TRAINING EXAMPLE")

print(train_data[0]["text"][:500])
print("...")

# Verify format
print("FORMAT VERIFICATION")
sample_text = train_data[0]["text"]
print(f"✓ Starts with <|system|>: {sample_text.startswith('<|system|>')}")
print(f"✓ Contains <|user|>: {'<|user|>' in sample_text}")
print(f"✓ Contains <|assistant|>: {'<|assistant|>' in sample_text}")
print(f"✓ Ends properly (no trailing user): {not sample_text.strip().endswith('<|user|>:')}")
print(f"✓ Has emotion tag: {'[emotion:' in sample_text}")

# Check for the bug (should be False)
has_bug = False
for sample in samples[:100]:
    text = sample["text"]
    # Check if assistant response is followed by another user message
    if "<|assistant|>:" in text:
        after_assistant = text.split("<|assistant|>:")[-1]
        if "<|user|>:" in after_assistant:
            # This is OK only if it's part of context, not after the final response
            parts = text.split("<|assistant|>:")
            if len(parts) > 2:  # Multiple assistant responses = OK (context)
                continue
            else:  # Single assistant response followed by user = BUG
                has_bug = True
                print(f"\nWARNING: Found bug in sample!")
                print(after_assistant[:200])
                break

if not has_bug:
    print("✓ No format bugs detected in first 100 samples!")

print("\n" + "="*60)
print("FIXED DATASET READY FOR TRAINING!")
print("\nNext steps:")
print("1. Upload Dataset.json to your training environment")
print("2. Run this script to generate data_fixed/")
print("3. Update training script to use data_fixed/train and data_fixed/valid")
print("4. Retrain the model")