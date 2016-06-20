require 'errors'

require 'json'
require 'pp'

class User
	attr_reader :id
	attr_reader :name
	attr_reader :dm_channel

	def initialize(id, name)
		@id = id
		@name = name
	end

	class << self
		attr_accessor :channel
		attr_reader :members
		attr_reader :user_cache


		def find(user_id)
			@user_cache ||= {}
			@user_cache[user_id] || cache_user(user_id)
		end

		# Find a user by name
		def with_name(user_name)
			@user_cache ||= {}
			user = @user_cache.values.find{|u| u.name == user_name}
			if user.nil?
				raise CommandError, "#{user_name} is not a member of the channel for the current game"
			end
			user
		end

		def load_client
			@client ||= Slack::Web::Client.new(token: ENV['SLACK_API_TOKEN'])
			@logger ||= SlackRubyBot::Client.logger
		end

		def load_members(channel)
			load_client
			@logger.info "Loading members of channel #{channel}"
			@members = @client.channels_info(channel: channel)['channel']['members']
			@members.each do |user_id|
				cache_user(user_id)
			end
		end

		def cache_user(user_id)
			load_client
			user_response = @client.users_info(user: user_id)
			user_info = user_response['user']
			user = User.new(user_id, user_info['name'])
			
			@user_cache ||= {}
			@user_cache[user_id] = user
			user
		end

		def uncache_user(user_id)
			@user_cache ||= {}
			@user_cache.delete user_id
		end
	end

	def ==(other_user)
		other_user.id == self.id
	end
end