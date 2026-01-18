import json
import os
from datasets import Dataset
from transformers import AutoTokenizer
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent

def tokenize_hierarchical_dataset(
    input_file=BASE_DIR / "preprocessed_data_hierarchical.json",
    output_dir=BASE_DIR / "tokenized_dataset_hierarchical",
    model_name="EleutherAI/gpt-neo-125M",
    max_length=768,
    test_split=0.2,
    seed=42,
):

    with open(input_file, "r", encoding="utf-8") as f:
        data = json.load(f)

    print(f"Loaded {len(data)} samples from {input_file}")

    tokenizer = AutoTokenizer.from_pretrained(model_name, use_fast=True)

    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token

    dataset = Dataset.from_list(data)

    def tokenize_function(batch):
        input_ids_batch = []
        labels_batch = []
        attention_masks = []

        for system, user, assistant in zip(
            batch["SYSTEM"], batch["User"], batch["Assistant"]
        ):

            system_text = system.strip() + "\n\n"
            user_text = f"User: {user.strip()}\n\n"
            assistant_text = assistant.strip()

            prompt_text = (
                system_text
                + user_text
                + "Assistant:\n"
            )

            prompt_ids = tokenizer(
                prompt_text, add_special_tokens=False
            ).input_ids

            answer_ids = tokenizer(
                assistant_text, add_special_tokens=False
            ).input_ids

            input_ids = prompt_ids + answer_ids

            labels = [-100] * len(prompt_ids) + answer_ids

            input_ids = input_ids[:max_length]
            labels = labels[:max_length]

            pad_len = max_length - len(input_ids)
            if pad_len > 0:
                input_ids += [tokenizer.pad_token_id] * pad_len
                labels += [-100] * pad_len

            attention_mask = [
                0 if token_id == tokenizer.pad_token_id else 1
                for token_id in input_ids
            ]

            input_ids_batch.append(input_ids)
            labels_batch.append(labels)
            attention_masks.append(attention_mask)

        return {
            "input_ids": input_ids_batch,
            "labels": labels_batch,
            "attention_mask": attention_masks,
        }
    
    tokenized_dataset = dataset.map(
        tokenize_function,
        batched=True,
        remove_columns=dataset.column_names,
        desc="Tokenizing clean hierarchical dataset",
    )

    split_dataset = tokenized_dataset.train_test_split(
        test_size=test_split,
        seed=seed
    )

    train_dataset = split_dataset["train"]
    val_dataset = split_dataset["test"]

    print(f"Train samples: {len(train_dataset)}")
    print(f"Validation samples: {len(val_dataset)}")

    os.makedirs(output_dir, exist_ok=True)

    train_dataset.save_to_disk(os.path.join(output_dir, "train"))
    val_dataset.save_to_disk(os.path.join(output_dir, "validation"))
    tokenizer.save_pretrained(os.path.join(output_dir, "tokenizer"))

    stats = {
        "total_samples": len(data),
        "train_samples": len(train_dataset),
        "val_samples": len(val_dataset),
        "model": model_name,
        "max_length": max_length,
        "loss_masking": "assistant_only",
        "answer_format": "plain_text",
        "hierarchy_preserved": True,
        "task": "mental_health_dialogue"
    }

    with open(os.path.join(output_dir, "stats.json"), "w", encoding="utf-8") as f:
        json.dump(stats, f, indent=2)

    print(f"Clean tokenized dataset saved to: {output_dir}")

    return train_dataset, val_dataset


if __name__ == "__main__":
    tokenize_hierarchical_dataset()
