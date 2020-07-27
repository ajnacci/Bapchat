These files define the majority of the way text
is interpreted throughout preprocessing and bot
activity.

NOTE: Usernames are formatted before being read
and compared to these files! Run the
users_detected.R script in 
model_generation/data_preprocessing/r_scripts
to see a list of what all usernames encountered
in the provided data look like once they're
compared to the following files. You then will
type the usernames you want AS THEY APPEAR IN
users_detected's OUTPUT.

bapchat_names.txt
This file holds all the names that your bot will
recognize as its own. One name per line. The file
includes the original bapchat alt names.

emoticons.txt
This file collapses sets of emoticons into
representative emoticons and one-word
descriptions (which are used as stand-ins in the
actual operation of the code). Whitespace is
stripped from either end of each entry, and each
row contains 3 entries, separated by tildes. The
first column is the stand-in value, the second
column is the representative emoticon (which the
bot will use in its texts), and the third column
contains a list of regexps (comma delimited) that
match emoticons to be collapsed into the second
column emoticon. Whitespace is removed from
either end of each regexp.

generic_names.txt
This file contains a list of names which are used
as stand-ins for different users. It helps the
bot learn how to deal with talking to multiple
people without learning specific names that
appear in the training data. You only need to
edit this if someone in your server goes by one
of these names, which may screw up the bot.
Really, any old random string of letters will do
as a replacement.

messages_to_ignore.txt
<desc coming soon>

reduction_words.txt
This file contains a list of words, one per line.
The underlying code reduces any string of
repeated letters (more than 3) to just one of the
letter, so if someone said "waffffle" it would
become "wafle". You see the issue. So if there's
a word people stretch out a lot in your server
that has a double letter, you should put it here.

replacement_text.txt
This is a file with two columns, tilde delimited.
In the first column, we have regular expressions
whose matches are replaced with the corresponding
text in the second column. If there is nothing in
the second column, the text is simply deleted.

replacement_words.txt
This is a file with two columns, tilde delimited.
The first column contains a regular expression
whose matches are replaced by the text in the
second column. This may seem like the same thing
as replacement_text, but there's a key
difference! These regexps are automatically
surrounded by start- and end-of-word detectors.
So, it won't match and replace the middle of a 
word, only the word itself. This is executed
BEFORE replacement_text.

special_replacement_text.txt
This is a file with three columns, tilde
delimited. The first column represents regular
expressions whose matches will be replaced by the
third column. However, the bot internally will
read these as the text in the second column. This
is important because you may want to make some
text look the same as another to the users, but
have the bot read them differently.

special_replacement_words.txt
This file is the same as the previous one, but
has start- and end-of-word detectors.
(see replacement_words.txt's description above)

usernames.txt
This file contains three columns, comma
delimited. The first column contains discord
usernames that the bot should recognize as names.
The second column contains a string that the bot
should use when referring to those users. The
third column contains a set of nicknames which
the bot will recognize as all representing the
corresponding user (along with the names in the
first and second columns, so no need for
repeating those). Users that send messages will
still be recognized by the bot, but only by their
full username unless they are included in this
file.

users_to_ignore.txt
This file contains a list of usernames which
should be altogether ignored. Bots are already
ignored, so there shouldn't be much use for this.
One name per line.

users_to_train_on.txt
Now this one is actually important and must be
changed. It contains a list of usernames of users
the bot should use during preprocessing and
training to learn from. If you only include one
user here, then the bot will essentially emulate
them.
