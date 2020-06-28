const Discord = require('discord.js');
const config = require('./config.json');
const status = require('./status_messages.json');
const errors = require('./error_messages.json');
const tokens = require('./tokens.json')
const msg_counter = require('./msg_counter.json')

//const fs = require('');
const client = new Discord.Client();

const R = require("r-script");
const express = require('express');

const fs = require('fs')

const {spawn} = require('child_process');

const VERSION_NUMBER = '3.4';
const MODEL_VERSION = '4.0';

var convo_messages = {}; //channel -> messages
var convo_authors = {}; //channel -> messages
var blocked_for_response = {}; //false; channel -> waiting for a response?

var queue_messages = {};
var queue_authors = {};

const model_folder = 'model_folder';

const ign = /&/;
const id_replacer = /<@!(\d{18})>/gi;

//discord stuff
client.on('ready', () => {
 console.log(`Logged in as ${client.user.tag}!`);
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
	//console.log(message.author)
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

	//message.guild.members.cache[the number string].user.username
	//message.author

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

		if(message.cleanContent === "@bapchat" || message.cleanContent === "@Bapchat"){
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
	sp_names = convert_text(message, authors, content);
	generate_response(message, sp_names);
}

function generate_response(message, speakerNames){
	let id_key = get_key(message);
	console.log('called generate_response');
	//if(!blocked_for_response[id_key]){
		blocked_for_response[id_key] = true;
		const python = spawn('python', [model_folder + '/run_generation.py', '--model_type=gpt2', '--length=200', '--model_name_or_path='+model_folder, '--input_text=./textfiles/' + message.channel.id + 'st.txt', '--num_generics=' + speakerNames.length]);
		python.stdout.on('data', function (data) {
  			//console.log('Pipe data from python script ...');
  			dataToSend = data.toString();
  			console.log(dataToSend);
  			fs.readFile('./textfiles/' + message.channel.id + 'st.txt', 'utf8', function(err, data2){
  				if (err) return console.log(err);
  				temp_data = data2 + dataToSend + '"'
  				console.log(temp_data)
  				dataToSend2 = R("./output_righter.R").data(dataToSend, speakerNames).callSync();
  				console.log(dataToSend2);
  				message.channel.send(dataToSend2);
  				if(message.guild === null){
  					convo_authors[id_key].push("Bapchat");
					convo_messages[id_key].push(dataToSend2);
  				}else{
  					enqueue_full("Bapchat", dataToSend2, id_key);
  				}
  			});
  			
  			//for(var index = 0; index < msgs_to_send.length; index++){
  			//	message.channel.send(msgs_to_send[index]);
  			//}
  			
  			msg_counter.msg_count = msg_counter.msg_count+1;
  			fs.writeFile('./config.json', JSON.stringify(config, null, 4), function writeJSON(err) {
  				if (err) return console.log(err);
			});
  			blocked_for_response[id_key] = false;
 		});
 		python.on('close', (code) => {
 			console.log(`child process close all stdio with code ${code}`);
 			blocked_for_response[id_key] = false;
 			// res.send(dataToSend)
 		});
 	
 	//}else{
 	//	console.log("Blocked, won't generate response");
 	//}
}

function reset_channel(message){
	let id_key = get_key(message);
	convo_messages[id_key] = new Array();
	convo_authors[id_key] = new Array();
	
	queue_messages[id_key] = new Array();
	queue_authors[id_key] = new Array();
	blocked_for_response[id_key] = false;
}

function get_key(message){
	return String(message.channel.id);
}

function convert_text(msg, authors, msgs){
	console.log(authors)
	console.log(msgs)
	r_conv = R("D:/SteamLibrary/Ajnac/Side\ projects/sfa/acci_two/" + model_folder + "/text_fixer.R").data(authors, msgs).callSync();
	converted_text = r_conv[0];
	speakerNames = r_conv[1];
	console.log(converted_text);
	console.log(speakerNames);
	fs.writeFile('./textfiles/' + msg.channel.id + 'st.txt', converted_text, function (err) {
		if (err) return console.log(err);
		console.log('saved converted text')
	});
	return speakerNames;
}

function ignore_message(message){
	return message.match(ign) != null;
}

function update_status(){
	client.user.setActivity('Written ' + msg_counter.msg_count + ' msgs, Bot v' + VERSION_NUMBER + ', Language model v' + MODEL_VERSION);
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

	if(content === "@bapchat"){
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