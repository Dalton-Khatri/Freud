import torch
from datasets import load_from_disk
from transformers import (
    AutoTokenizer,
    AutoModelForCausalLM,
    Trainer,
    TrainingArguments,
    DataCollatorForLanguageModeling
)


MODEL_NAME = "EleutherAI/gpt-neo-125M"
dataset_base = "Freud/tokenizer/prompt_response_pair_dataset/data"
TRAIN_DATASET_PATH = f"{dataset_base}/train"
VALID_DATASET_PATH = f"{dataset_base}/valid"
OUTPUT_DIR = "Freud/freud_model"

MAX_LENGTH = 512
BATCH_SIZE = 2
GRAD_ACCUM_STEPS = 8
LEARNING_RATE = 2e-5
EPOCHS = 3
FP16 = torch.cuda.is_available()

train_dataset = load_from_disk(TRAIN_DATASET_PATH)
valid_dataset = load_from_disk(VALID_DATASET_PATH)

print("Train samples:", len(train_dataset))
print("Valid samples:", len(valid_dataset))

tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)

if tokenizer.pad_token is None:
    tokenizer.pad_token = tokenizer.eos_token

def tokenize(batch):
    return tokenizer(
        batch["text"],
        truncation=True,
        padding="max_length",
        max_length=MAX_LENGTH
    )

train_dataset = train_dataset.map(
    tokenize,
    batched=True,
    remove_columns=["text"]
)

valid_dataset = valid_dataset.map(
    tokenize,
    batched=True,
    remove_columns=["text"]
)

data_collator = DataCollatorForLanguageModeling(
    tokenizer=tokenizer,
    mlm=False
)

model = AutoModelForCausalLM.from_pretrained(MODEL_NAME)

model.resize_token_embeddings(len(tokenizer))

training_args = TrainingArguments(
    output_dir=OUTPUT_DIR,
    overwrite_output_dir=True,

    per_device_train_batch_size=BATCH_SIZE,
    per_device_eval_batch_size=BATCH_SIZE,

    gradient_accumulation_steps=GRAD_ACCUM_STEPS,

    num_train_epochs=EPOCHS,
    learning_rate=LEARNING_RATE,

    fp16=FP16,

    logging_steps=50,
    save_steps=500,      
    do_eval=True,        
    eval_steps=500,      

    report_to="none"
)

trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=train_dataset,
    eval_dataset=valid_dataset,
    data_collator=data_collator,
)

trainer.train()

trainer.save_model(f"{OUTPUT_DIR}/final")
tokenizer.save_pretrained(f"{OUTPUT_DIR}/final")

print("Training complete!")
