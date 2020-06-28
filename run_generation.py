#!/usr/bin/env python3
# coding=utf-8
# Copyright 2018 Google AI, Google Brain and Carnegie Mellon University Authors and the HuggingFace Inc. team.
# Copyright (c) 2018, NVIDIA CORPORATION.  All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
""" Conditional text generation with the auto-regressive models of the library (GPT/GPT-2/CTRL/Transformer-XL/XLNet)
"""


import argparse
import logging
import random

import numpy as np
import torch
import re

from transformers import (
    CTRLLMHeadModel,
    CTRLTokenizer,
    GPT2LMHeadModel,
    GPT2Tokenizer,
    OpenAIGPTLMHeadModel,
    OpenAIGPTTokenizer,
    TransfoXLLMHeadModel,
    TransfoXLTokenizer,
    XLMTokenizer,
    XLMWithLMHeadModel,
    XLNetLMHeadModel,
    XLNetTokenizer,
)

generic_names = [
  'Jake',
  'Emily',
  'Mike',
  'Hannah',
  'Matt',
  'Maddy',
  'Josh',
  'Ashley',
  'Chris',
  'Sarah',
  'Nick',
  'Alex',
  'Andrew',
  'Sam',
  'Joseph',
  'Jessica',
  'Beth',
  'Tyler',
  'Taylor',
  'William',
  'Lauren',
  'Brandon',
  'Alyssa',
  'Ryan',
  'Kayla',
  'John',
  'Zach',
  'Brianna',
  'David',
  'Olivia',
  'Anthony',
  'Emma',
  'James',
  'Megan'
]

#patterns = [r"\(aa\)", r"\(mm\)", r"\(keysmashing\)"]
#replacements = ["aaaaAAAa", "mmmmMMMm", "asldkfjsjlafj"]

logging.basicConfig(
    format="%(asctime)s - %(levelname)s - %(name)s -   %(message)s", datefmt="%m/%d/%Y %H:%M:%S", level=logging.INFO,
)
logger = logging.getLogger(__name__)

MAX_LENGTH = int(10000)  # Hardcoded max length to avoid infinite loop

MODEL_CLASSES = {
    "gpt2": (GPT2LMHeadModel, GPT2Tokenizer)
}

def set_seed(args):
    np.random.seed(args.seed)
    torch.manual_seed(args.seed)
    if args.n_gpu > 0:
        torch.cuda.manual_seed_all(args.seed)


def adjust_length_to_model(length, max_sequence_length):
    if length < 0 and max_sequence_length > 0:
        length = max_sequence_length
    elif 0 < max_sequence_length < length:
        length = max_sequence_length  # No generation bigger than model size
    elif length < 0:
        length = MAX_LENGTH  # avoid infinite loop
    return length


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--model_type",
        default=None,
        type=str,
        required=True,
        help="Model type selected in the list: " + ", ".join(MODEL_CLASSES.keys()),
    )
    parser.add_argument(
        "--model_name_or_path",
        default=None,
        type=str,
        required=True,
        help="Path to pre-trained model or shortcut name selected in the list: " + ", ".join(MODEL_CLASSES.keys()),
    )

    parser.add_argument("--input_text", type=str, default=None)
    parser.add_argument("--prompt", type=str, default="")
    parser.add_argument("--length", type=int, default=20)
    parser.add_argument("--stop_token", type=str, default="<|endoftext|>", help="Token at which text generation is stopped")

    parser.add_argument(
        "--temperature",
        type=float,
        default=1.0,
        help="temperature of 1.0 has no effect, lower tend toward greedy sampling",
    )
    parser.add_argument(
        "--repetition_penalty", type=float, default=1.1, help="primarily useful for CTRL model; in that case, use 1.2"
    )
    parser.add_argument("--k", type=int, default=7)
    parser.add_argument("--p", type=float, default=0.9)

    parser.add_argument("--padding_text", type=str, default="", help="Padding text for Transfo-XL and XLNet.")
    parser.add_argument("--xlm_language", type=str, default="", help="Optional language when used with the XLM model.")
# random.randint(0,999999)
    parser.add_argument("--seed", type=int, default=random.randint(0,999999), help="random seed for initialization")
    parser.add_argument("--no_cuda", action="store_true", help="Avoid using CUDA when available")
    parser.add_argument("--num_return_sequences", type=int, default=1, help="The number of samples to generate.")
    parser.add_argument("--num_generics", type=int, default=1, help="Generic names used")

    args = parser.parse_args()
    args.device = torch.device("cuda" if torch.cuda.is_available() and not args.no_cuda else "cpu")
    args.n_gpu = 0 if args.no_cuda else torch.cuda.device_count()

    set_seed(args)

    # Initialize the model and tokenizer
    try:
        args.model_type = args.model_type.lower()
        model_class, tokenizer_class = MODEL_CLASSES[args.model_type]
    except KeyError:
        raise KeyError("the model {} you specified is not supported. You are welcome to add it and open a PR :)")

    tokenizer = tokenizer_class.from_pretrained(args.model_name_or_path)
    model = model_class.from_pretrained(args.model_name_or_path)
    model.to(args.device)

    args.length = adjust_length_to_model(args.length, max_sequence_length=model.config.max_position_embeddings)
    logger.info(args)

    prompt_text = ""
    while prompt_text != "***":
        prompt_text = args.prompt if args.prompt else (open(args.input_text, "r")).read() if args.input_text else input("Model prompt >>> ")
        encoded_prompt = tokenizer.encode(prompt_text, add_special_tokens=False, return_tensors="pt")
        encoded_prompt = encoded_prompt.to(args.device)

        if encoded_prompt.size()[-1] == 0:
            input_ids = None
        else:
            input_ids = encoded_prompt

        output_sequences = model.generate(
            input_ids=input_ids,
            max_length=args.length + len(encoded_prompt[0]),
            temperature=args.temperature,
            top_k=args.k,
            top_p=args.p,
            repetition_penalty=args.repetition_penalty,
            do_sample=True,
            num_return_sequences=args.num_return_sequences,
        )

        # Remove the batch dimension when returning multiple sequences
        if len(output_sequences.shape) > 2:
            output_sequences.squeeze_()

        generated_sequences = []

        found_extrageneric = False

        for generated_sequence_idx, generated_sequence in enumerate(output_sequences):
            # print("=== GENERATED SEQUENCE {} ===".format(generated_sequence_idx + 1))
            generated_sequence = generated_sequence.tolist()


            generated_sequence = generated_sequence[encoded_prompt.size()[1]:(-1 if args.stop_token else None)]
            # Decode text
            text = tokenizer.decode(generated_sequence, clean_up_tokenization_spaces=True)

            
            # Remove all text after the stop token
            # 
            text = text[(text.find("\"")+1): (text.rfind("\""))]# if args.stop_token else None]

            # If it contains too many generics, re-generate until it doesn't
            index = args.num_generics
            
            #print(text)

            found_extrageneric = 'Bapchat' in text or ('@' in text and not ' ' in text)
            while index < len(generic_names) and not found_extrageneric:
                found_extrageneric = generic_names[index] in text or text == "(link)" or text == "(emoji)" or text == "(attachment)"
                index = index + 1
            
            if found_extrageneric:
                #print(text)
                #print('EXTRA!')
                break

            # Add the prompt at the beginning of the sequence. Remove the excess text that was used for pre-processing
            #total_sequence = (
            #    prompt_text + text[len(tokenizer.decode(encoded_prompt[0], clean_up_tokenization_spaces=True)) :]
            #)

            #for index in 0:length(patterns):
            #   text = re.sub(patterns[index], replacements[index], text)
            

            #generated_sequences.append(total_sequence)
            #print(total_sequence)
            print(text)

        if not found_extrageneric and (args.input_text or args.prompt):
            return generated_sequences

    return generated_sequences


if __name__ == "__main__":
    main()

