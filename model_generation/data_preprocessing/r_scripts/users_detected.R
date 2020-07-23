library(data.table)

path_to_folder = "..//datasets//<folder containing csv files>"


file_list <- list.files(path_to_folder)

i = 1
temp <- NULL
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

temp[, short_author := iconv(Author, from = 'UTF-8', to = 'ASCII//TRANSLIT', sub="")]
#temp[, short_author := substring(short_author, 1, nchar(short_author)-5)]
temp[, short_author := gsub("[^0-9a-z\\(\\)\\?\\.\\$@%, ]", "", tolower(short_author))]

unau = unique(temp$short_author)
substring(unau, 1, nchar(unau)-4)