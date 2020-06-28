needs(data.table)
needs(dplyr)
needs(rlist)
needs(stringr)
needs(hash)
needs(sets)

sep_token = "\n <|endoftext|>\n "

# nameset: hash, name -> set of nicknames
# generic_names: number -> list of generic names
nameset <- hash()

model_folder <- './model_folder'
read_vec <- function(file_name){return(trimws(as.matrix(read.table(paste(model_folder, '/', file_name, '.txt', sep=''), sep=','))))}
split_multicol <- function(multicol){return(lapply(strsplit(multicol, ','), trimws))}

generic_names <- read_vec('generic_names')[, 1] 
nickname_mappings <- read_vec('usernames')

key_strings <- nickname_mappings[,1]
nick_list <- nickname_mappings[,2]
nicknames <- split_multicol(nickname_mappings[,3])

bap_names <- as.set(read_vec('bapchat_names')[,1])

for(i in 1:length(key_strings)){
  nameset[[key_strings[[i]]]] <- as.set(nicknames[[i]])
  nameset[[key_strings[[i]]]] <- set_union(set_union(as.set(key_strings[[i]]), nameset[[key_strings[[i]]]]), as.set(nick_list[[i]]))
}


remove_users <- c('FurBot', 'Dyno', '', 'Dante Beta', 'Frost', 'TeXit', 'Dooker', 'YAGPDBxyz', 'Majik')
remove_content <- c('f', 'F', '', 'pinned a message.', '^', '^^')


line_separator <- ', '

# use this for words with repeated characters that are likely to get held out (normal reduction loses the double letter)
words_to_reduce <- c("well", "ree", "oof", "ooh", "cool", "awoo", 
                     "hiss", "shh", "omg", "hello", "hi", "hey", 
                     "skippy", "acci", "waffles", "skip", "wtf", 
                     "she", "he", "his", "hers", "him", "her")

reduced_form <- words_to_reduce

test_fnt <- function(split_string){
  still_in <- rep(TRUE, length(split_string))
  rep_count <- rep(0, length(split_string))
  for(j in 1:(length(split_string)-1)){
    still_in <- still_in & split_string == c(split_string, rep("", j))[(1+j):(length(split_string)+j)]
    rep_count[!still_in & rep_count == 0] = j
  }
  spstr <- split_string
  spstr <- ifelse(rep_count==1, paste(spstr, "+", sep=""), spstr)
  return(paste(spstr, collapse=""))
}

words_to_reduce <- strsplit(words_to_reduce, split="")
for(i in 1:length(words_to_reduce)){
  words_to_reduce[[i]] <- test_fnt(words_to_reduce[[i]])
}


# surround with
st_rep_start <- "(\\s|^|\\(|\")"
st_rep_end <- "(\\s|$|,|\"|\\.|\\)|\\?|!)"
wordify <- function(reges){ return(paste(st_rep_start, reges, st_rep_end, sep="")) }
wordify2 <- function(reges){return(paste("\\1", reges, "\\2", sep=""))}
wordify3 <- function(reges){ return(paste("(\\s|^|\\(|\"|\\@)", reges, "(\\s|$|,|\"|\\.|\\)|:|s|\\?|!)", sep="")) }

full_emoticons <- read_vec('emoticons')
emoticon_index <- full_emoticons[,1]
emoticons <- split_multicol(full_emoticons[,3])


for(i in 1:length(emoticons)){
  emoticons[[i]] <- paste('(?:', emoticons[[i]], ')', sep='')
  emoticons[[i]] <- paste(emoticons[[i]], collapse='|')
}

emoticons <- wordify(emoticons)
emoticon_index <- wordify2(emoticon_index)


st_rep_sensor <- c(
  words_to_reduce,
  "o",
  "w+h*e{2,}",
  "a{2,}h*",
  "h+u*m+",
  "d*a+w+h*",
  "m+",
  "a*(?:h+a+)+h*",
  "[jy]+[ea]+h*",
  "u+",
  "v+i+n+x+",
  "l+e+(?:s|s{3,})",
  "s?he",
  "h(?:is|er)",
  "him",
  "hers",
  "himself",
  "herself"
)
st_rep_sensor <- wordify(st_rep_sensor)

# surround with \\1 \\2
st_rep_with <- c(
  reduced_form,
  "oh",
  "wee",
  "(ah)",
  "hmm",
  "aww",
  "(em)",
  "haha",
  "yeah",
  "you",
  "mexi",
  "les",
  "they",
  "their",
  "them",
  "theirs",
  "themselves",
  "themselves"
)
st_rep_with <- wordify2(st_rep_with)

# if a message matches these, set it to empty
regex_message_delete <- c("^,tex", "^d\\.", "^\\?[:alpha:]+")
paste(regex_message_delete, ".*$")
#"^\\(emoji\\)( \\(emoji\\))*$",

rep_sensor <- c(
  "^d\\..*", #boat command removal (just destroys whole message)
  "http\\S+", #(link) detector
  "^\\s*f\\.shind.*$",
  "^f\\.(\\S+)",
  "\n+",
  "\\s+", #excess whitespace removal (should be performed directly before spaced letter detection and after newline replace)
  "(( |^)([:alpha:])){3,}", #spaced-out-letters detector
  "([[:alpha:]])\\1{2,}", #rep reducer. 3+ goes to 1 **********************************
  "\\.{2,}", #convert any number of multiple dots to an elipses (3 dots)
  "@{2,}",
  "[:alpha:]{18,}", #label words (after rep-reduction) of length 20+ as keymashing. This number can probably be lower
  "\\?{4,}", #remove long sequences of ? since these may come from iconv
  "\\S*[asdfghjkl]{12,}\\S*",
  st_rep_sensor,
  regex_message_delete
)

rep_with <-  c( # subtract 39 to get other line number
  "", 
  "(link)", 
  "",
  "",
  line_separator,
  " ", 
  " (spaced-out-letters) ", 
  "\\1", 
  "...",
  "@",
  " (keymashing) ", 
  "", 
  "(keysmashing)",
  st_rep_with,
  rep("", length(regex_message_delete))
)


temp <- data.table(
  Author = input[[1]],
  Content = input[[2]]
)

temp[, short_author := iconv(Author, from = 'UTF-8', to = 'ASCII//TRANSLIT', sub="")]
temp[, Content := iconv(Content, from = 'UTF-8', to = 'ASCII//TRANSLIT', sub="")]

#Experimental: get these out of the way because they screw things up otherwise
#temp[, Content := ifelse(is.na(Attachments) | Attachments == "", Content, paste(Content, "(attachment)"))]
#temp[, Attachments := NULL]
temp[, Content := str_replace_all(Content, ":\\S+:(\\d{18})?", " (emoji) ")]
temp[, Content := str_replace_all(Content, "http\\S+", " (link) ")]
temp[, Content := str_replace_all(Content, "\\?\\\\_\\(\\?\\)_/\\?", " (shrug) ")]
temp[, Content := str_replace_all(Content, wordify("we're"), wordify2("we are"))]

temp[, fixed_content := tolower(Content)]

for(i in 1:length(emoticons)){
  temp[, fixed_content := str_replace_all(fixed_content, emoticons[[i]], emoticon_index[[i]])]
}

#
#temp[, Reactions := NULL]
temp[, Content := NULL]
#temp[, Date := NULL]

#temp[, fixed_content := gsub("\n+", ", ", fixed_content)]

temp[, fixed_content := gsub("[^0-9a-z:;\\(\\)\\?\\^\\./$@%\\[\\]\\<\\>, ]", "", fixed_content)]
#temp[, fixed_content := gsub("['\"]", "", fixed_content)]
#temp[, short_author := gsub("[^a-zA-Z]", "", iconv(short_author, from = 'UTF-8', to = 'ASCII//TRANSLIT', sub=""))]
#temp[, fixed_content := gsub(":[^ ]*;", "(emoji)", fixed_content)]

temp <- temp[!(short_author %in% remove_users)]

for(j in 1:length(rep_sensor)){
  temp[, fixed_content := str_replace_all(fixed_content, rep_sensor[[j]], rep_with[[j]])]
}

temp[, fixed_content := trimws(fixed_content)]
temp <- temp[!(fixed_content %in% remove_content)]
# 15 further refine symbols
temp[, fixed_content := gsub("[^0-9a-z\\(\\)\\?\\.\\$@%, ]", "", fixed_content)]
temp[, short_author := gsub("[^0-9a-z\\(\\)\\?\\.\\$@%, ]", "", tolower(short_author))]
temp <- temp[grepl("^[0-9a-z\\.\\$@%, ]+$", short_author)]
#temp[, short_author := gsub("[^a-z]", "", tolower(short_author))]

# Experimental: filter out all length 1 messages
# temp <- temp[nchar(temp$fixed_content) > 1]
#

shift <- function(input, n){
  return(c(rep("",n), input[1:(length(input)-n)]))
}


if(nrow(temp)>1){
  k = 1
  uns = temp[['short_author']]
  shi = shift(uns,1)
  shifted = list()
  shifted[[k]] = uns == shi
  k = k + 1
  shi = shift(uns, k)
  while(any((uns == shi) & shifted[[k-1]])){
    shifted[[k]] = (uns == shi) & shifted[[k-1]]
    k = k + 1
    shi = shift(uns, k)
  }
  
  k = k - 1
  temp[, combi := 0]
  for(i2 in 1:k){
    temp[shifted[[i2]], combi := i2]
  }
  
  
  temp[, Author := NULL]
  temp[, Content := NULL]
  #temp[, AuthorID := NULL]
  
  temp[, id := 1:nrow(temp)]
  acc <- temp[combi == 0]
  
  rm(shi, uns)
  
  setkey(acc, id)
  for(i2 in 1:k){
    tempo <- temp[combi == i2]
    tempo <- tempo[, id := id-i2]
    setkey(tempo, id)
    acc <- merge(acc, tempo, all=TRUE)
    acc[, fixed_content := ifelse(is.na(fixed_content.y) | fixed_content.x == fixed_content.y, fixed_content.x, paste(fixed_content.x, fixed_content.y, sep=line_separator))]
    acc[, combi := combi.x]
    acc[, short_author := short_author.x]
    acc[, fixed_content.x := NULL]
    acc[, combi.x := NULL]
    acc[, short_author.x := NULL]
    acc[, fixed_content.y := NULL]
    acc[, combi.y := NULL]
    acc[, short_author.y := NULL]
  }
  
  temp <- acc
  
  rm(acc, tempo, shifted)
  
  
} else {
  temp[, Author := NULL]
  #temp[, Content := NULL]
  
}


temp[, fixed_content := trimws(fixed_content)]
#print(paste(nrow(temp[nchar(fixed_content) < 2]), nrow(temp[nchar(fixed_content) < 3]), nrow(temp[nchar(fixed_content) < 4]), nrow(temp[nchar(fixed_content) < 5]), 'out of', nrow(temp), sep=', '))
#temp[, untagged_fixed_content := fixed_content]
# KEY LINE TODO SWITCH BETWEEN USAGES
temp[, fixed_content := paste(short_author, ': "', fixed_content, '"', sep='')]
#temp[, fixed_content := paste('__label__', short_author, ' ', fixed_content, sep='')]

#for(j in 1:length(post_rep_sensor)){
#  temp[, fixed_content := gsub(post_rep_sensor[[j]], post_rep_with[[j]], fixed_content)]
#}

#TODO count backwards some number of characters from the end of the message


# UPDATED VERSION: acci 2 :3
texts = temp$fixed_content

bap_nameset <- as.set(
  c(
    'bapchat',
    'bappy',
    'dave',
    'acci 2',
    'Bapchat'
  )
)




name_format <- function(ttso){
  name_mappings <- list()
  tts <- ttso
  tag_locations <- str_locate_all(pattern=":", tts)
  full_nameset <- bap_nameset
  for(b_name in bap_nameset){
    tts <- str_replace_all(tts, wordify3(b_name), wordify2("Bapchat"))
  }
  identifier <- 1
  if(length(tag_locations)> 0){
    
    temp_nameset <- NULL
    temp_name <- NULL
    for(j in length(tag_locations):1){
      tag_locations <- str_locate_all(pattern=":", tts)
      temp_name <- substring(tts[j], 1, tag_locations[[j]][1,'start']-1)
      if(!set_contains_element(full_nameset, temp_name) && !(temp_name %in% generic_names)){
        temp_nameset <- nameset[[temp_name]]
        name_mappings[[identifier]] <- temp_name
        if(is.null(temp_nameset)){
          temp_nameset <- as.set(temp_name)
        }
        full_nameset <- set_union(full_nameset, temp_name)
        for(name in temp_nameset){
          tts <- str_replace_all(tts, wordify3(name), wordify2(generic_names[[identifier]]))
        }
        
        identifier <- identifier + 1
        
      }
    }
  }
  
  for(name in key_strings){
    if(!set_contains_element(full_nameset, name)){
      move_on <- FALSE
      for(pat in wordify3(nameset[[name]])){
        if(!move_on){
          move_on <- any(grepl(pattern=pat, tts))
        }
      }
      if(move_on){
        temp_name <- name
        
        print(identifier)
        print(temp_name)
        name_mappings[[identifier]] <- temp_name
        temp_nameset <- nameset[[temp_name]]
        if(is.null(temp_nameset)){
          temp_nameset <- as.set(temp_name)
        }
        full_nameset <- set_union(full_nameset, temp_name)
        for(name in temp_nameset){
          tts <- str_replace_all(tts, wordify3(name), wordify2(generic_names[[identifier]]))
        }
        
        identifier <- identifier + 1
      }
    }
  }
  
  return(list(paste(c(tts, 'Bapchat: '), collapse='\n'), name_mappings))
  
}


temp_texts <- texts
name_format(temp_texts)


