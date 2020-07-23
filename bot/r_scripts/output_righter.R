needs(stringr)
needs(hash)
needs(sets)

rel_specification_path <- '..//..//text_replacement_defs//'

setwd(input[[3]])

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

split_multicol <- function(multicol){return(lapply(strsplit(multicol, ','), trimws))}

wordify31 <- function(reges){ return(paste("(\\s|^|\\(|\"|\\@)", reges, "(\\s|$|,|\"|\\.|\\)|s|:|!|\\?)", sep="")) }
wordify2 <- function(reges){return(paste("\\1", reges, "\\2", sep=""))}
wordify32 <- function(reges){ return(paste("(\\s|^|\\(|\"|\\@)", reges, "(:)", sep="")) }
wordify33 <- function(reges){ return(wordify31(paste('\\(', reges, '\\)', sep=""))) }


generic_names <- read_vec('generic_names')

nickname_mappings <- read_vec('usernames')
key_strings <- get_col2(nickname_mappings,1)
nick_list <- get_col2(nickname_mappings,2)

full_emoticons <- read_vec2(c('emoticons', '~'))
base_emoticons <- get_col2(full_emoticons,2)
data_rep_emoticons <- substr(get_col2(full_emoticons,1), 2, nchar(get_col2(full_emoticons,1))-1)

special_replacement_words <- read_vec('special_replacement_words')
special_replacement_text <- read_vec('special_replacement_text')

reps_todo <- hash(
  keys=c(
    base_emoticons,
    get_col2(special_replacement_words,2),
    get_col2(special_replacement_text,2)
  ),
  values=c(
    data_rep_emoticons,
    get_col2(special_replacement_words,1),
    get_col2(special_replacement_text,1)
  )
)


# maps key_string to nickname
nicknames <- hash()
if(length(key_strings)>0){
  for(i in 1:length(key_strings)){
    nicknames[[key_strings[[i]]]] <- nick_list[[i]]
  }
}

osr <- input[[1]]
corr <- input[[2]]

temp <- osr

if(length(corr)>0){
  for(i in 1:length(corr)){
    if(!(corr[[i]] %in% keys(nicknames))){
      temp <- str_replace_all(temp, wordify31(generic_names[[i]]), wordify2(corr[[i]]))
    }else{
      temp <- str_replace_all(temp, wordify31(generic_names[[i]]), wordify2(nicknames[[corr[[i]]]]))
      temp <- str_replace_all(temp, wordify32(nicknames[[corr[[i]]]]), wordify2(corr[[i]]))
    }
  }
}
  
temp <- str_replace_all(temp, '(\\s)\\1+', '\\1')

tkeys <- keys(reps_todo)
if(length(tkeys) > 0){
  for(i in 1:length(tkeys)){
    temp <- str_replace_all(temp, wordify33(reps_todo[[tkeys[[i]]]]), wordify2(tkeys[[i]]))
  }
}

temp