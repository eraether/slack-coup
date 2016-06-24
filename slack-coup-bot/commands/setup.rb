require 'commands/base'

module SlackCoupBot
	module Commands
		class Setup < Base
			class << self
				def open_lobby(client, channel, **game_options)
					client.say text: "Loading the Coup lobby...", channel: channel

					self.client = client
					self.channel = channel
					self.game = Game.new(channel, game_options)
					User.load_members(channel)

					bot_info = client.web_client.auth_test
					SlackRubyBot.configure do |c|
						c.user = bot_info['user']
						c.user_id = bot_info['user_id']
					end
				end
			end


			match /^(coup-)help$/ do |client, data|
				client.say text: "Not yet implemented. Check out the README: https://github.com/ericfields/slack-coup/blob/master/README.md", channel: data.channel
			end

			match /^coup-debug$/ do |client, data, match|
				logger.info "Received request to initiate debugging game"
				if data.channel[0] == 'D'
					raise CommandError, "Can't debug - you're in a direct message channel"
					next
				end

				open_lobby(client, data.channel, self.debug_options)

				max_players = self.debug_options[:max_players] || 6
				User.all_users.select{|u| u.id != SlackRubyBot.config.user_id}.first(max_players).sort_by{|u| u.name}.each do |user|
					game.add_player user
				end

				start_game
			end

			match /^coup-lobby$/ do |client, data, match|
				logger.info "Received request to open a coup lobby"

				if data.channel[0] == 'D'
					client.say text: "You can't start a lobby in a direct message channel. Run this command in a general Slack channel.", channel: data.channel
					next
				end

				if game
					if game.started?
						client.say text: "There is already a game under way.\n\nPlayers:\n\n#{game.player_list}", channel: data.channel
					else
						client.say text: "A lobby for Coup is already open, so shut up.\n\nPlayers:\n\n#{game.player_list}", channel: data.channel
					end
					next
				end

				open_lobby(client, data.channel)

				game.add_player data.user

				client.say text: "A new lobby for a game of Coup has been opened.\n\nPlayers:\n\n#{game.player_list}", channel: data.channel
				client.say text: "You can join, leave, invite, or kick players with `coup-join`, `coup-leave`, `coup-invite`, `coup-kick`", channel: data.channel
				client.say text: "You can start the game with `coup-start`, or end the game and close the lobby with `coup-end`", channel: data.channel
			end

			match /^coup-start$/ do |client, data|
				logger.info "Received request to start game"
				if game.nil?
					client.say text: "No Coup lobby has been opened", channel: data.channel
				elsif game.started?
					client.say text: "A game of Coup is already under way.", channel: data.channel
				elsif game.players.count < 4
					client.say text: "Not enough players for a game of Coup. A minimum of 4 players is required.", channel: data.channel
				
				else
					start_game
				end
			end

			match /^coup-join$/ do |client, data|
				if game.nil?
					client.say text: "No game has been started. Start a new game of Coup by typing 'lobby'.", channel: data.channel
					next
				end

				if game.players == 6
					client.say text: "You cannot join - there is already a maximum of 6 players in this game.", channel: data.channel
					next
				end

				if game.players[data.user]
					client.say text: "You are already in the game.", channel: data.channel
					next
				end

				player = game.add_player data.user

				client.say text: "#{player} has joined the game.\n\nPlayers:\n\n#{game.player_list}", channel: data.channel
			end

			match /^coup-leave$/ do |client, data|
				next if game.nil?

				removed_player = game.remove_player data.user

				next if removed_player.nil?

				client.say text: "#{removed_player} has left the game.\n\nPlayers:\n\n#{game.player_list}", channel: data.channel
				
				if game.players.count == 0
					end_game

					client.say text: "No players are in the Coup lobby. The lobby is now closed.", channel: data.channel
				end
			end

			match /^coup-invite (?<players>(\w+(\s+)?)+)/ do |client, data, match|
				player_names = match[:players].split ' '

				player_names.each do |player_name|
					user = User.with_name(player_name)
					if user.nil?
						client.say text: "*#{player_name}* is not a member of the channel for the current game", channel: data.channel
						next
					end
					player = game.add_player user.id
					client.say text: "Added #{player} to the game.", channel: data.channel
				end

				client.say text: "Players:\n\n#{game.player_list}", channel: data.channel

			end

			match /^coup-kick (?<players>(\w+(\s+)?)+)/ do |client, data, match|
				player_names = match[:players].split ' '

				users = player_names.collect do |player_name|
					user = User.with_name(player_name)
					if user.nil?
						raise CommandError, "#{user_name} is not a member of the channel for the current game"
					end
					user
				end

				users.each do |user|
					removed_player = game.remove_player user.id
					if removed_player
						client.say text: "Removed #{player_names} from the game", channel: data.channel
					else
						client.say text: "Player #{user.name} is not in the game", channel: data.channel
					end
				end
			end

			match /^status/ do |client, data, match|
				if game.nil?
					client.say text: "No lobby is currently open for Coup.", channel: data.channel
				elsif ! game.started?
					client.say text: "A lobby for Coup is currently open.\n\nPlayers:\n\n#{game.player_list}", channel: data.channel
				else
					sleep 0.3
					client.say text: "A game of Coup is under way.\n\nStatus:\n\n#{game.status}", channel: data.channel
					client.say text: "It is now #{game.current_player}'s turn to act.", channel: data.channel
				end
			end

			match /^coup-end/ do |client, data|
				next if game.nil?

				end_game
				client.say text: "This game of Coup has ended.", channel: data.channel
			end
		end
	end
end