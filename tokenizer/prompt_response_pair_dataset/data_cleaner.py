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

OUTPUT_TRAIN_DIR = BASE_DIR / "data/train"
OUTPUT_VAL_DIR = BASE_DIR / "data/valid"

VALID_SPLIT = 0.1
RANDOM_SEED = 42

SYSTEM_PROMPT = (
    "You are Freud, a calm, empathetic therapeutic AI assistant. "
    "You respond thoughtfully, kindly, and supportively. "
    "You ask gentle follow-up questions and never judge the user."
)

MAX_MULTI_TURN = 2

random.seed(RANDOM_SEED)

with open(INPUT_FILE, "r", encoding="utf-8") as f:
    dataset = json.load(f)

intents = dataset["intents"]
samples = []

def single_turn(emotion, user, assistant):
    return (
        f"<|system|>: {SYSTEM_PROMPT}\n"
        f"<|user|>:\n"
        f"[emotion: {emotion}]\n"
        f"{user.strip()}\n"
        f"<|assistant|>:\n"
        f"{assistant.strip()}"
    )


def multi_turn(emotion, turns):
    convo = f"<|system|>: {SYSTEM_PROMPT}\n"
    for user, assistant in turns:
        convo += (
            f"<|user|>:\n"
            f"[emotion: {emotion}]\n"
            f"{user.strip()}\n"
            f"<|assistant|>:\n"
            f"{assistant.strip()}\n"
        )
    return convo.strip()

for intent in intents:
    emotion = intent.get("tag", "neutral")
    patterns = intent.get("patterns", [])
    responses = intent.get("responses", [])

    if not patterns or not responses:
        continue

    for p in patterns:
        r = random.choice(responses)
        samples.append({"text": single_turn(emotion, p, r)})

    if len(patterns) >= 2:
        for i in range(len(patterns) - 1):
            turns = []
            for t in range(MAX_MULTI_TURN):
                idx = i + t
                if idx >= len(patterns):
                    break
                turns.append((patterns[idx], random.choice(responses)))

            if len(turns) >= 2:
                samples.append({"text": multi_turn(emotion, turns)})


random.shuffle(samples)

save_json(BASE_DIR / "data" / "all_preprocessed.json", samples)

train_data, val_data = train_test_split(
    samples,
    test_size=VALID_SPLIT,
    random_state=RANDOM_SEED
)

save_json(BASE_DIR / "data" / "train.json", train_data)
save_json(BASE_DIR / "data" / "valid.json", val_data)

train_dataset = Dataset.from_list(train_data)
val_dataset = Dataset.from_list(val_data)

train_dataset.save_to_disk(OUTPUT_TRAIN_DIR)
val_dataset.save_to_disk(OUTPUT_VAL_DIR)

print("Arrow dataset created successfully")
print(f"Train samples: {len(train_dataset)}")
print(f"Valid samples: {len(val_dataset)}")
