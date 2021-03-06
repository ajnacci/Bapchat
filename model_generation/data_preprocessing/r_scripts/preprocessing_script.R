
library(data.table)
library(dplyr)
library(stringr)
library(hash)
library(sets)


path_to_folder = "..//datasets//<dataset to process>"
path_to_output_folder = "..//processed_data//<folder to write processed data into>"

rel_specification_path <- '..//..//..//text_replacement_defs//'


max_tokens = 80
sep_token = "\n <|endoftext|>\n "
line_separator <- ', '

# surround with
st_rep_start <- "(\\s|^|\\(|\")"
st_rep_end <- "(\\s|$|,|\"|\\.|\\)|\\?|!)"
wordify <- function(reges){ return(paste(st_rep_start, reges, st_rep_end, sep="")) }
wordify2 <- function(reges){return(paste("\\1", reges, "\\2", sep=""))}
wordify3 <- function(reges){ return(paste("(\\s|^|\\(|\"|\\@)", reges, "(\\s|$|,|\"|\\.|\\)|:|s|\\?|!)", sep="")) }

generic_error_default <- function(fn, default_val, inputs){
  outer = default_val
  try(
    (outer = fn(inputs)),
    silent=TRUE
  )
  return(outer)
}

gen_generic_ed <- function(fn, default_val){
  return(function(inputs) return(generic_error_default(fn, default_val, inputs)))
}

read_vec_pre <- function(file_name){
  return(trimws(as.matrix(read.table(paste(rel_specification_path, file_name, '.txt', sep=''), sep=','))))
}

read_vec2_pre <- function(inputs){
  file_name = inputs[1]
  sept = inputs[2]
  return(trimws(as.matrix(read.table(paste(rel_specification_path, file_name, '.txt', sep=''), sep=sept))))
}

read_vec <- gen_generic_ed(read_vec_pre, as.matrix(character()))
read_vec2 <- gen_generic_ed(read_vec2_pre, as.matrix(character()))

get_col <- gen_generic_ed(function(inputs) return(inputs[[1]][,inputs[[2]]]), character())
get_col2 <- function(a, b){get_col(list(a,b))}

# nameset: hash, name -> set of nicknames
# generic_names: number -> list of generic names
nameset <- hash()

split_multicol <- function(multicol){return(lapply(strsplit(multicol, ','), trimws))}

generic_names <- get_col2(read_vec('generic_names'), 1)
nickname_mappings <- read_vec('usernames')

key_strings <- get_col2(nickname_mappings,1)
nick_list <- get_col2(nickname_mappings,2)
nicknames <- split_multicol(get_col2(nickname_mappings,3))

#bap_names <- as.set(get_col(list(read_vec('bapchat_names'),1)))

for(i in 1:length(key_strings)){
  nameset[[key_strings[[i]]]] <- as.set(nicknames[[i]])
  nameset[[key_strings[[i]]]] <- set_union(set_union(as.set(key_strings[[i]]), nameset[[key_strings[[i]]]]), as.set(nick_list[[i]]))
}

get_nameset <- function(query){
  if(query %in% keys(nameset)){
    return(nameset[[query]])
  }
  return(as.set(query))
}


remove_users <- read_vec("users_to_ignore")
remove_content <- read_vec("messages_to_ignore")

# use this for words with repeated characters that are likely to get held out (normal reduction loses the double letter)
words_to_reduce <- get_col2(read_vec('reduction_words'),1)

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

full_emoticons <- read_vec2(c('emoticons', '~'))
emoticon_index <- get_col2(full_emoticons,1)
emoticons <- split_multicol(get_col2(full_emoticons,3))


for(i in 1:length(emoticons)){
  emoticons[[i]] <- paste('(?:', emoticons[[i]], ')', sep='')
  emoticons[[i]] <- paste(emoticons[[i]], collapse='|')
}

emoticons <- wordify(emoticons)
emoticon_index <- wordify2(emoticon_index)

replacement_words <- read_vec2(c("replacement_words", "~"))
special_replacement_words <- read_vec2(c("special_replacement_words", "~"))

st_rep_sensor <- c(
  words_to_reduce,
  get_col2(replacement_words,1),
  get_col2(special_replacement_words,1)
)
st_rep_sensor <- wordify(st_rep_sensor)

# surround with \\1 \\2
st_rep_with <- c(
  reduced_form,
  get_col2(replacement_words,2),
  get_col2(special_replacement_words,2)
)
st_rep_with <- wordify2(st_rep_with)

# if a message matches these, set it to empty
regex_message_delete <- c("^,tex", "^d\\.", "^\\?[:alpha:]+")
paste(regex_message_delete, ".*$")

replacement_text <- read_vec2(c("replacement_text", "~"))
special_replacement_text <- read_vec2(c("special_replacement_text", "~"))

rep_sensor <- c(
  "\n+",
  "\\s+", #excess whitespace removal (should be performed directly before spaced letter detection and after newline replace)
  get_col2(replacement_text,1),
  get_col2(special_replacement_text,1),
  st_rep_sensor,
  regex_message_delete
)

rep_with <-  c( # subtract 39 to get other line number
  line_separator,
  " ", 
  get_col2(replacement_text,2),
  get_col2(special_replacement_text,2),
  st_rep_with,
  rep("", length(regex_message_delete))
)

file_list <- list.files(path_to_folder)

i = 1
temp <- NULL
print('READING CSV FILES (step 1 of 4)')
for(file_name in file_list){
  print(paste('i', i, ' out of ', length(file_list)))
  file_name2 <- paste(path_to_folder, file_name, sep='//')
  if(i == 1){
    temp <- fread(file_name2, colClasses=c("character"), encoding="UTF-8")
  }else{
    temp <- rbind(temp, fread(file_name2, colClasses=c("character"), encoding="UTF-8"))
  }
  i = i + 1
}

temp[, AuthorID := NULL]
temp[, Date := NULL]
temp[, Reactions := NULL]

temp[, short_author := iconv(Author, from = 'UTF-8', to = 'ASCII//TRANSLIT', sub="")]
temp[, short_author := substring(short_author, 1, nchar(short_author)-4)]
temp[, Content := iconv(Content, from = 'UTF-8', to = 'ASCII//TRANSLIT', sub="")]

#Experimental: get these out of the way because they screw things up otherwise
temp[, Content := ifelse(is.na(Attachments) | Attachments == "", Content, paste(Content, "(attachment)"))]
temp[, Attachments := NULL]
temp[, Content := str_replace_all(Content, ":\\S+:(\\d{18})?", " (emoji) ")]
temp[, Content := str_replace_all(Content, "http\\S+", " (link) ")]
temp[, Content := str_replace_all(Content, "\\?\\\\_\\(\\?\\)_/\\?", " (shrug) ")]
temp[, Content := str_replace_all(Content, wordify("we're"), wordify2("we are"))]

temp[, fixed_content := tolower(Content)]

for(i in 1:length(emoticons)){
  temp[, fixed_content := str_replace_all(fixed_content, emoticons[[i]], emoticon_index[[i]])]
}

temp[, Content := NULL]
temp[, fixed_content := gsub("[^0-9a-z:;\\(\\)\\?\\^\\./$@%\\[\\]\\<\\>, ]", "", fixed_content)]

temp <- temp[!(short_author %in% remove_users)]

print('DOING REPLACEMENTS (step 2 of 4)')
for(j in 1:length(rep_sensor)){
  print(paste('doing replacement ', j, ' of ', length(rep_sensor), sep=''))
  temp[, fixed_content := str_replace_all(fixed_content, rep_sensor[[j]], rep_with[[j]])]
  
}

temp[, fixed_content := trimws(fixed_content)]
temp <- temp[!(fixed_content %in% remove_content)]
# 15 further refine symbols
temp[, fixed_content := gsub("[^0-9a-z\\(\\)\\?\\.\\$@%, ]", "", fixed_content)]
temp[, short_author := gsub("[^0-9a-z\\(\\)\\?\\.\\$@%, ]", "", tolower(short_author))]
temp <- temp[grepl("^[0-9a-z\\.\\$@%, ]+$", short_author)]

# Experimental: filter out all length 1 messages
# temp <- temp[nchar(temp$fixed_content) > 1]
#

shift <- function(input, n){
  return(c(rep("",n), input[1:(length(input)-n)]))
}


print('MERGING CONSECUTIVE MESSAGES (step 3 of 4)')
if(nrow(temp)>1){
  print('detecting max merge')
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
    print(paste('merge ' , i2, ' out of ', k, sep=''))
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
}


temp[, fixed_content := trimws(fixed_content)]
temp[, fixed_content := paste(short_author, ': "', fixed_content, '"', sep='')]

texts = temp$fixed_content


print('BREAKING INTO TRAINING BLOCKS (final step)')
name_format <- function(ttso){
  name_mappings <- list()
  tts <- ttso
  tag_locations <- str_locate_all(pattern=":", tts)
  ######
  bap_nameset <- get_nameset(substring(tts[length(tts)], 1, tag_locations[[length(tts)]][1,'start']-1))
  ######
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
        
        #print(identifier)
        #print(temp_name)
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

indices = numeric()
people_to_learn_from <- read_vec('users_to_train_on')

for(i in 1:length(people_to_learn_from)){
  indices = c(indices, which(grepl(paste('^',  people_to_learn_from[[i]], sep=''), texts)))
}


token_length <- function(ind, c_s){
  return(
    length(
      strsplit(
        trimws(
          str_replace_all(
            paste(
              texts[max(1, ind-c_s):ind], collapse=' '
              ), " +", " ")
          ), " ")[[1]])
    )
}

result_lines = list()
max_count = length(indices)
int_step = round(max_count/100)
counter = 1
counter2 = 1
for(index in indices){
  context_size <- 0
  while(token_length(index, context_size) < max_tokens & max(1,index-context_size) > 1){
    context_size <- context_size + 1
  }
  if(context_size > 0){
    context_size <- context_size - 1
  }
  temp_texts <- texts[max(1, index-context_size):index]
  
  temp_texts <- name_format(temp_texts)
  
  result_lines <- append(result_lines, c(paste(temp_texts, collapse='\n')))
  if(counter%%int_step==0){
    print(paste('approx. ', counter2, '% complete', sep=''))
    counter2 = counter2 + 1
  }
  counter = counter+1
}

train_indices <- sample(1:(length(result_lines)), round(0.9*length(result_lines)))
train_lines <- result_lines[1:(length(result_lines)) %in% train_indices]
test_lines <- result_lines[!(1:(length(result_lines)) %in% train_indices)]

fileConn <- file(paste(path_to_output_folder, 'train.txt', sep='\\'))
train_lines <- unlist(append(append(c(""), train_lines), c("")))
writeLines(train_lines, fileConn, sep=sep_token)
close(fileConn)

test_lines <- unlist(append(append(c(""), test_lines), c("")))
fileConn <- file(paste(path_to_output_folder, 'val.txt', sep='\\'))
writeLines(test_lines, fileConn, sep=sep_token)
close(fileConn)

print("Done! You can find the processed data in train.txt and val.txt in the specified output folder.")
