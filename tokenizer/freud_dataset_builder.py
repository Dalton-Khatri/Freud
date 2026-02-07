import json
import random
import os
from pathlib import Path
from typing import List, Dict, Tuple
from collections import defaultdict


# Configuration
RANDOM_SEED = 42
TRAIN_SPLIT = 0.9  # 90% train, 10% validation
MAX_CONVERSATION_LENGTH = 512  # tokens
AUGMENTATION_FACTOR = 1.2  # Create 20% more samples through augmentation

# Set random seed for reproducibility
random.seed(RANDOM_SEED)


class FreudDatasetBuilder:
    """
    Builds an enhanced training dataset for Freud mental health assistant.
    
    Features:
    - Response variation to prevent repetition
    - Multi-turn conversation generation
    - Emotion-based balancing
    - Proper format for transformer training
    """
    
    def __init__(self, input_file: str, output_dir: str = "freud_training_data"):
        self.input_file = input_file
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        
        # System prompt (same as your original)
        self.system_prompt = (
            "You are Freud, a calm, empathetic therapeutic AI assistant. "
            "You respond thoughtfully, kindly, and supportively. "
            "You ask gentle follow-up questions and never judge the user."
        )
        
        self.data = None
        self.samples = []
        self.stats = defaultdict(int)
    
    def load_data(self):
        """Load the original Dataset.json file"""
        print(f" Loading dataset from {self.input_file}...")
        
        with open(self.input_file, 'r', encoding='utf-8') as f:
            self.data = json.load(f)
        
        intents = self.data.get('intents', [])
        print(f" Loaded {len(intents)} intents")
        
        # Print some statistics
        total_patterns = sum(len(intent.get('patterns', [])) for intent in intents)
        total_responses = sum(len(intent.get('responses', [])) for intent in intents)
        
        print(f" Dataset Stats:")
        print(f"   - Total Patterns: {total_patterns}")
        print(f"   - Total Responses: {total_responses}")
        print(f"   - Avg Patterns/Intent: {total_patterns/len(intents):.1f}")
        
        return self
    
    def create_single_turn_sample(self, emotion: str, user_msg: str, assistant_msg: str) -> str:
        """
        Create a single-turn conversation in the training format.
        
        Format:
        <|system|>: [system prompt]
        <|user|>:
        [emotion: {emotion}]
        {user message}
        <|assistant|>:
        {assistant response}
        """
        return (
            f"<|system|>: {self.system_prompt}\n"
            f"<|user|>:\n"
            f"[emotion: {emotion}]\n"
            f"{user_msg.strip()}\n"
            f"<|assistant|>:\n"
            f"{assistant_msg.strip()}"
        )
    
    def create_multi_turn_sample(self, emotion: str, turns: List[Tuple[str, str]]) -> str:
        conversation = f"<|system|>: {self.system_prompt}\n"
        
        for user_msg, assistant_msg in turns:
            conversation += (
                f"<|user|>:\n"
                f"[emotion: {emotion}]\n"
                f"{user_msg.strip()}\n"
                f"<|assistant|>:\n"
                f"{assistant_msg.strip()}\n"
            )
        
        return conversation.strip()
    
    def augment_response(self, response: str, emotion: str) -> str:
        """
        Add slight variations to responses to prevent memorization.
        This doesn't change the meaning, just makes it more natural.
        """
        # Simple augmentation: sometimes add empathetic prefixes
        prefixes = {
            'sad': ['I hear you. ', 'I understand. ', 'That sounds difficult. '],
            'anxious': ['I can sense your worry. ', 'Anxiety can be tough. ', ''],
            'stressed': ['Stress is real. ', 'That sounds overwhelming. ', ''],
            'angry': ['I hear your frustration. ', 'It\'s okay to feel angry. ', ''],
            'happy': ['I\'m glad to hear that! ', 'That\'s wonderful! ', ''],
        }
        
        if emotion in prefixes and random.random() < 0.3:  # 30% chance to add prefix
            prefix = random.choice(prefixes[emotion])
            if response and not response.startswith(prefix.strip()):
                return prefix + response
        
        return response
    
    def build_dataset(self):
        """Main method to build the enhanced dataset"""
        print("\nBuilding enhanced dataset...")
        
        intents = self.data.get('intents', [])
        
        for intent in intents:
            emotion = intent.get('tag', 'neutral')
            patterns = intent.get('patterns', [])
            responses = intent.get('responses', [])
            
            if not patterns or not responses:
                continue
            
            # Create single-turn samples
            for pattern in patterns:
                response = random.choice(responses)
                
                # Optionally augment the response
                if random.random() < 0.3:  # 30% augmentation
                    response = self.augment_response(response, emotion)
                
                sample = self.create_single_turn_sample(emotion, pattern, response)
                self.samples.append({'text': sample})
                self.stats['single_turn'] += 1
                self.stats[f'emotion_{emotion}'] += 1
            
            # Create multi-turn samples (if enough patterns)
            if len(patterns) >= 2:
                # Create conversations of 2-3 turns
                for i in range(len(patterns) - 1):
                    num_turns = min(random.randint(2, 3), len(patterns) - i)
                    turns = []
                    
                    for j in range(num_turns):
                        if i + j < len(patterns):
                            user_msg = patterns[i + j]
                            asst_msg = random.choice(responses)
                            turns.append((user_msg, asst_msg))
                    
                    if len(turns) >= 2:
                        sample = self.create_multi_turn_sample(emotion, turns)
                        self.samples.append({'text': sample})
                        self.stats['multi_turn'] += 1
        
        print(f"Created {len(self.samples)} samples")
        print(f"   - Single-turn: {self.stats['single_turn']}")
        print(f"   - Multi-turn: {self.stats['multi_turn']}")
        
        return self
    
    def split_and_save(self):
        """Split into train/validation and save to disk"""
        print(f"\nSplitting and saving dataset...")
        
        # Shuffle samples
        random.shuffle(self.samples)
        
        # Split
        split_idx = int(len(self.samples) * TRAIN_SPLIT)
        train_samples = self.samples[:split_idx]
        val_samples = self.samples[split_idx:]
        
        print(f"Split: {len(train_samples)} train, {len(val_samples)} validation")
        
        # Save JSON files
        train_file = self.output_dir / "train.json"
        val_file = self.output_dir / "validation.json"
        
        with open(train_file, 'w', encoding='utf-8') as f:
            json.dump(train_samples, f, ensure_ascii=False, indent=2)
        
        with open(val_file, 'w', encoding='utf-8') as f:
            json.dump(val_samples, f, ensure_ascii=False, indent=2)
        
        print(f"Saved to {self.output_dir}/")
        print(f"   - {train_file}")
        print(f"   - {val_file}")
        
        # Save statistics
        stats_file = self.output_dir / "dataset_stats.json"
        stats = {
            'total_samples': len(self.samples),
            'train_samples': len(train_samples),
            'val_samples': len(val_samples),
            'single_turn': self.stats['single_turn'],
            'multi_turn': self.stats['multi_turn'],
            'emotions': {k: v for k, v in self.stats.items() if k.startswith('emotion_')}
        }
        
        with open(stats_file, 'w', encoding='utf-8') as f:
            json.dump(stats, f, indent=2)
        
        print(f"Statistics saved to {stats_file}")
        
        return self
    
    def show_samples(self, n: int = 3):
        """Display a few sample conversations for inspection"""
        print(f"\nSample Conversations:\n")
        
        for i in range(min(n, len(self.samples))):
            sample = self.samples[i]['text']
            print(f"Sample {i+1}:")
            # Show first 400 characters
            print(sample[:400] + ('...' if len(sample) > 400 else ''))
            print()


def main():
    """Main execution function"""
    print(" Freud Mental Health AI - Dataset Builder")
    
    # Check if Dataset.json exists
    if not os.path.exists('Dataset.json'):
        print("   Error: Dataset.json not found in current directory!")
        print("   Please place your Dataset.json file here and run again.")
        return
    
    # Build the dataset
    builder = FreudDatasetBuilder('Dataset.json')
    builder.load_data()
    builder.build_dataset()
    builder.show_samples(n=2)  # Show 2 samples for verification
    builder.split_and_save()
    print("Dataset preparation complete!")

if __name__ == "__main__":
    main()