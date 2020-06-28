needs(stringr)
needs(hash)
needs(sets)

model_folder <- './model_folder'
read_vec <- function(file_name){return(trimws(as.matrix(read.table(paste(model_folder, '/', file_name, '.txt', sep=''), sep=','))))}
split_multicol <- function(multicol){return(lapply(strsplit(multicol, ','), trimws))}

generic_names <- read_vec('generic_names')

nickname_mappings <- read_vec('usernames')
key_strings <- nickname_mappings[,1]
nick_list <- nickname_mappings[,2]

full_emoticons <- read_vec('emoticons')
base_emoticons <- full_emoticons[,2]
data_rep_emoticons <- substr(full_emoticons[,1], 2, nchar(full_emoticons[,1])-1)


reps_todo <- hash(
  keys=c(
    base_emoticons,
    'aaaaaAaa',
    'mmmmMMm',
    'asldfkjkdlfjslja'
  ),
  values=c(
    base_emoticons,
    'ah',
    'em',
    'keymashing',
  )
)


# maps key_string to nickname
nicknames <- hash()
for(i in 1:length(key_strings)){
  nicknames[[key_strings[[i]]]] <- nick_list[[i]]
}

wordify31 <- function(reges){ return(paste("(\\s|^|\\(|\"|\\@)", reges, "(\\s|$|,|\"|\\.|\\)|s|:|!|\\?)", sep="")) }
wordify2 <- function(reges){return(paste("\\1", reges, "\\2", sep=""))}
wordify32 <- function(reges){ return(paste("(\\s|^|\\(|\"|\\@)", reges, "(:)", sep="")) }
wordify33 <- function(reges){ return(wordify31(paste('\\(', reges, '\\)', sep=""))) }

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
  
temp <- str_replace_all(temp, wordify31('mew'), '')
temp <- str_replace_all(temp, '(\\s)\\1+', '\\1')

tkeys <- keys(reps_todo)
for(i in 1:length(tkeys)){
  temp <- str_replace_all(temp, wordify33(reps_todo[[tkeys[[i]]]]), wordify2(tkeys[[i]]))
}

temp