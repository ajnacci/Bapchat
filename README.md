# Bapchat
A discord chatbot based on GPT2 and trained on relatively small message contexts.

I am still working on documenting everything fully, but here is what you need to know in order to use Bapchat:
1. You must have [RStudio](https://rstudio.com/) and [Python 3](https://www.python.org/downloads/release/python-385/) installed (any version of Python 3 should work, but I used and thus linked to 3.8.5).
2. You must then install pytorch via pip: pip3 install torch torchvision
3. You should have at least 5 GB of space for this project.
4. There are direction folders in all the important places that tell you what you need to do. Start with the one in /model_generation/data_preprocessing.

Good luck!

Note: I did not write the run_language_model.py and run_generation.py files. I only adjusted them a bit from the examples provided by the transformers (huggingface) library. All other code is my own, pending comments.
