--[[
        Copyright (c) 2014 Kevin Smith
        Licensed under the GNU General Public License v3.
        See LICENSE for more information.
--]]

package.path = './locallua/lib/lua/5.1/?.lua;./locallua/share/lua/5.1/?.lua;'..package.path
package.cpath = './locallua/lib/lua/5.1/?.so;'..package.cpath

require('socket.http')
require('sluift')
require('json')
require('ssl.https')

xmpp_jid = os.getenv("SLUIFT_JID")
xmpp_pass = os.getenv("SLUIFT_PASS")
muc_room = os.getenv("MUC_ROOM")
muc_jid = muc_room.."/Trello"
trello_oauth_key = os.getenv("TRELLO_KEY")
trello_oauth_token = os.getenv("TRELLO_TOKEN")
trello_board = os.getenv("TRELLO_BOARD")
polling_time = 60
--polling_time = 10

sluift.debug = true

xmpp = sluift.new_client(xmpp_jid, xmpp_pass)



function sleep(seconds)
	i = 0
	while i < seconds do
		socket.select(nil, nil, 1)  -- Just so C-c responds more quickly
		i = i + 1
	end
end

function form_message(event)
	local person = event['memberCreator']['fullName']
	local message = nil
	local description = nil
	local type = event['type']
	if type == 'createCard' then
		description = "created a card in list '"..event['data']['list']['name'].."' : '"..event['data']['card']['name'].."'."
	elseif type == 'updateCard' then
		local old = event['data']['old']
		local name = event['data']['card']['name']
		if old.name then
			description = "renamed '".. old.name .."' to '"..name.."'"
		elseif old.idList then
			description = "moved '"..name.."' from '"..event.data.listBefore.name.."' to '"..event.data.listAfter.name.."'"
		elseif old.closed ~= nil then
			description = "archived '"..name.."'"
		end
	elseif type == 'commentCard' then
		description = "added a comment to '"..event.data.card.name.."':\n"..event.data.text
	end
	if description then
		message = person..' '..description
	end
	return message
end


xmpp:connect(function ()
	xmpp:send_presence{to = muc_jid}
	print("Connected")
	local first = true
	local newest = ''
	while true do
		local boardURL = 'https://api.trello.com/1/board/'..trello_board..'/actions?key='..trello_oauth_key
		if trello_oauth_token and trello_oauth_token ~= '' then
				boardURL = boardURL..'&token='..trello_oauth_token
		end
		content, code, headers = ssl.https.request(boardURL)
		if content ~= "" then
			local data = json.decode(content)
			newNewest = newest
			for _, item in pairs(data) do
				local date = item['date']
				if date > newest then
					if date > newNewest then
						newNewest = date
					end
					if not first then
						print("Found new data: ")
						sluift.tprint(item)
						local message = form_message(item)
						if message then
							print(message)
							xmpp:send_message{to=muc_room, body=message, type='groupchat'}
						end
					end
				end
			end
			newest = newNewest
			first = false
			olddata = data
		end
		sleep(polling_time)
	end
end)
