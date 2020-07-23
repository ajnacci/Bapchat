const Discord = require('discord.js');
const config = require('./config.json');
const model_folder = config.model_folder;
const status = require('./data_files/status_messages.json');
const errors = require('./data_files/error_messages.json');
const tokens = require('./data_files/tokens.json');

//const fs = require('');
const client = new Discord.Client();

const R = require("r-script");
const express = require('express');

const fs = require('fs');

const {spawn} = require('child_process');

const VERSION_NUMBER = config.version;
const MODEL_VERSION = config.model_name;

var convo_messages = {}; //channel -> messages
var convo_authors = {}; //channel -> messages

var queue_messages = {};
var queue_authors = {};



const ign = /&/;
const id_replacer = /<@!(\d{18})>/gi;

var msg_count = 0;

fs.readFile('./data_files/msg_count.txt', function(err, data){
	if(!err){
		msg_count = Number(data);
	}
});

//discord stuff
client.on('ready', () => {
 console.log(`Logged in as ${client.user.username}!`);
 update_status();
 });

function get_username(message, id_n){
	if(message.guild === null){
		message.channel.send('Note: I ignore pings in DMs.');
		return('');
	}
	return(message.guild.members.cache.get(id_n).user.username);
}

client.on('message', message => {
	if(message.author.bot){
		return;
	}

	let t_arr = [...message.content.matchAll(id_replacer)];
	let i = 0;
	let fixed_content = message.content;
	while(i < t_arr.length){
		fixed_content = fixed_content.replace(t_arr[i][0], get_username(message, t_arr[i][1]));
		i = i+1;
	}

	if(!(String(message.channel.id) in queue_messages) && !(String(message.channel.id) in convo_messages)){
		console.log('Creating ' + message.channel.id);
		reset_channel(message);
	}
	
	let id_key = get_key(message);

	if(message.content.startsWith(config.prefix)){
		message_handler(message);
	} else {
		if (message.guild === null){
			convo_authors[id_key].push(message.author.username);
			convo_messages[id_key].push(fixed_content);
			response_process(message, convo_authors[id_key], convo_messages[id_key]);
		} else{
			enqueue(message, fixed_content);
			if(message.mentions.has(client.user)){
				response_process(message, queue_authors[id_key], queue_messages[id_key]);
			}
		}

		if(message.cleanContent === "@" + client.user.username){
			message.delete();
		}
	}
	
	update_status();
});
	
function message_handler(message){
	const args = message.content.slice(config.prefix.length).split(/ +/);
	const command = args.shift().toLowerCase();
	const id_key = get_key(message);

	if(message.guild === null){
		console.log("DM received from " + message.author.username + ": " + message.cleanContent);
	}

	if (!config.valid_commands.includes(command)){
		message.channel.send(errors.general.invalid_command);
		return;
	}

	if(command === "reset"){
		reset_channel(message);
		message.channel.send("Reset!");
		return;
	}

	if(command === "help"){
		message.author.send(build_multiline_string(status.help_string));
		return;
	}

}

function response_process(message, authors, content){
	const ctout = convert_text(message, authors, content);
	generate_response(message, ctout[0], ctout[1]);
}

function generate_response(message, speakerNames, file_id){
	let id_key = get_key(message);
	console.log('called generate_response');
	var model_to_use = model_folder;
	console.log(file_id);
	const python = spawn('python', [model_folder + '/run_generation.py', '--model_type=gpt2', '--length=200', '--model_name_or_path='+model_to_use, '--input_text=./data_files/async_pipeline/' + file_id + 'st.txt', '--num_generics=' + speakerNames.length]);
	python.stdout.on('data', function (data) {
  		var dataToSend = data.toString().substring(0,data.toString().length-1);
  		console.log(dataToSend);
  		fs.readFile('./data_files/async_pipeline/' + file_id + 'st.txt', 'utf8', function(err, data2){
  			if (err) return console.log(err);
  			dataToSend2 = R("./r_scripts/output_righter.R").data(dataToSend, speakerNames, process.cwd() + "\\r_scripts").callSync();
  			console.log(dataToSend2);
  			message.channel.send(dataToSend2);
  			if(message.guild === null){
  				convo_authors[id_key].push("Bapchat");
				convo_messages[id_key].push(dataToSend2);
  			}else{
  				enqueue_full("Bapchat", dataToSend2, id_key);
  			}
  		});
 
 		msg_count = msg_count + 1;
  		fs.writeFileSync('./data_files/msg_count.txt', msg_count);
 	});
 	
 	python.on('close', (code) => {
 		if(code != 0){
			message.channel.send(status_messages.ml.response_generation_default);
		}
		console.log(`child process close all stdio with code ${code}`);		
 	});
 	
}

function reset_channel(message){
	let id_key = get_key(message);
	convo_messages[id_key] = new Array();
	convo_authors[id_key] = new Array();
	
	queue_messages[id_key] = new Array();
	queue_authors[id_key] = new Array();
}

function get_key(message){
	return String(message.channel.id);
}

function get_userkey(message, user){
	return String(message.channel.id).concat(' ', String(user.id));
}

function getRandomInt(msg) {
	var max = 10000;
	return (Math.floor(Math.random() * Math.floor(max)) + msg.channel.id + msg.author.id) % max;
}

function convert_text(msg, authors, msgs){
	const file_id = String(getRandomInt(msg));
	console.log(authors);
	console.log(msgs);
	r_conv = R("./r_scripts/text_fixer.R").data(authors, msgs, process.cwd() + "\\r_scripts").callSync();
	converted_text = r_conv[0];
	speakerNames = r_conv[1];
	console.log(converted_text);
	fs.writeFileSync('./data_files/async_pipeline/' + file_id + 'st.txt', converted_text);
	return [speakerNames, file_id];
}

function ignore_message(message){
	return message.match(ign) != null;
}

function update_status(){
	client.user.setActivity('Written ' + msg_count + ' msgs, Bot v' + VERSION_NUMBER + ', Language model v' + MODEL_VERSION);
}

function enqueue(message){
	enqueue_full(message.author.username, message.cleanContent, get_key(message));
}

function build_multiline_string(string_list){
	acc = "";
	for(string_segment in string_list){
		acc = acc + string_segment;
	}
	return(acc);
}

function enqueue_full(author, content, id_key){
	let context_size = config.context_size;

	if(!queue_authors[id_key]){
		queue_messages[id_key] = new Array();
		queue_authors[id_key] = new Array();
	
	}

	if(content === "@" + client.user.username){
		return;
	}

	if(author === queue_authors[id_key][queue_authors[id_key].length - 1]){
		queue_messages[id_key][queue_authors[id_key].length - 1] = queue_messages[id_key][queue_authors[id_key].length - 1] + config.line_separator + content;
		return;
	}
	if(queue_authors[id_key].length < context_size){
		queue_authors[id_key].push(author);
		queue_messages[id_key].push(content);
	}else{
		var i;
		for(i = 0; i < context_size - 1; i++){
			queue_authors[id_key][i] = queue_authors[id_key][i+1];
			queue_messages[id_key][i] = queue_messages[id_key][i+1];
		}
		queue_authors[id_key][context_size - 1] = author;
		queue_messages[id_key][context_size - 1] = content;
	}
	
}


client.login(tokens.token);