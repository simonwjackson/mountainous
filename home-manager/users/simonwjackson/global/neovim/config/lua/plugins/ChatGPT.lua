-- A Neovim plugin that allows you to generate natural language responses from OpenAI’s
-- ChatGPT directly within the editor

return {
	{
		"robitx/gp.nvim",
		lazy = false,
		dependencies = {
			"MunifTanjim/nui.nvim",
			"nvim-lua/plenary.nvim",
			"nvim-telescope/telescope.nvim",
		},
		keys = {
			-- VISUAL mode mappings
			{ "<C-g>c", ":<C-u>'<,'>GpChatNew<cr>", desc = "Visual Chat New", mode = "v" },
			{ "<C-g>v", ":<C-u>'<,'>GpChatPaste<cr>", desc = "Visual Chat Paste", mode = "v" },
			{ "<C-g>t", ":<C-u>'<,'>GpChatToggle<cr>", desc = "Visual Popup Chat", mode = "v" },
			{ "<C-g>r", ":<C-u>'<,'>GpRewrite<cr>", desc = "Visual Rewrite", mode = "v" },
			{ "<C-g>a", ":<C-u>'<,'>GpAppend<cr>", desc = "Visual Append", mode = "v" },
			{ "<C-g>b", ":<C-u>'<,'>GpPrepend<cr>", desc = "Visual Prepend", mode = "v" },
			{ "<C-g>e", ":<C-u>'<,'>GpEnew<cr>", desc = "Visual Enew", mode = "v" },
			{ "<C-g>p", ":<C-u>'<,'>GpPopup<cr>", desc = "Visual Popup", mode = "v" },
			{ "<C-g>s", "<cmd>GpStop<cr>", desc = "Stop", mode = "v" },
			{ "<C-g>w", ":<C-u>'<,'>GpWhisper<cr>", desc = "Whisper", mode = "v" },
			{ "<C-g>R", ":<C-u>'<,'>GpWhisperRewrite<cr>", desc = "Whisper Visual Rewrite", mode = "v" },
			{ "<C-g>A", ":<C-u>'<,'>GpWhisperAppend<cr>", desc = "Whisper Visual Append", mode = "v" },
			{ "<C-g>B", ":<C-u>'<,'>GpWhisperPrepend<cr>", desc = "Whisper Visual Prepend", mode = "v" },
			{ "<C-g>E", ":<C-u>'<,'>GpWhisperEnew<cr>", desc = "Whisper Visual Enew", mode = "v" },
			{ "<C-g>P", ":<C-u>'<,'>GpWhisperPopup<cr>", desc = "Whisper Visual Popup", mode = "v" },

			-- NORMAL mode mappings
			{ "<C-g>c", "<cmd>GpChatNew<cr>", desc = "New Chat", mode = "n" },
			{ "<C-g>t", "<cmd>GpChatToggle<cr>", desc = "Toggle Popup Chat", mode = "n" },
			{ "<C-g>f", "<cmd>GpChatFinder<cr>", desc = "Chat Finder", mode = "n" },
			{ "<C-g>r", "<cmd>GpRewrite<cr>", desc = "Inline Rewrite", mode = "n" },
			{ "<C-g>a", "<cmd>GpAppend<cr>", desc = "Append", mode = "n" },
			{ "<C-g>b", "<cmd>GpPrepend<cr>", desc = "Prepend", mode = "n" },
			{ "<C-g>e", "<cmd>GpEnew<cr>", desc = "Enew", mode = "n" },
			{ "<C-g>p", "<cmd>GpPopup<cr>", desc = "Popup", mode = "n" },
			{ "<C-g>s", "<cmd>GpStop<cr>", desc = "Stop", mode = "n" },
			{ "<C-g>w", "<cmd>GpWhisper<cr>", desc = "Whisper", mode = "n" },
			{ "<C-g>R", "<cmd>GpWhisperRewrite<cr>", desc = "Whisper Inline Rewrite", mode = "n" },
			{ "<C-g>A", "<cmd>GpWhisperAppend<cr>", desc = "Whisper Append", mode = "n" },
			{ "<C-g>B", "<cmd>GpWhisperPrepend<cr>", desc = "Whisper Prepend", mode = "n" },
			{ "<C-g>E", "<cmd>GpWhisperEnew<cr>", desc = "Whisper Enew", mode = "n" },
			{ "<C-g>P", "<cmd>GpWhisperPopup<cr>", desc = "Whisper Popup", mode = "n" },

			-- INSERT mode mappings
			{ "<C-g>c", "<cmd>GpChatNew<cr>", desc = "New Chat", mode = "i" },
			{ "<C-g>t", "<cmd>GpChatToggle<cr>", desc = "Toggle Popup Chat", mode = "i" },
			{ "<C-g>f", "<cmd>GpChatFinder<cr>", desc = "Chat Finder", mode = "i" },
			{ "<C-g>r", "<cmd>GpRewrite<cr>", desc = "Inline Rewrite", mode = "i" },
			{ "<C-g>a", "<cmd>GpAppend<cr>", desc = "Append", mode = "i" },
			{ "<C-g>b", "<cmd>GpPrepend<cr>", desc = "Prepend", mode = "i" },
			{ "<C-g>e", "<cmd>GpEnew<cr>", desc = "Enew", mode = "i" },
			{ "<C-g>p", "<cmd>GpPopup<cr>", desc = "Popup", mode = "i" },
			{ "<C-g>s", "<cmd>GpStop<cr>", desc = "Stop", mode = "i" },
			{ "<C-g>w", "<cmd>GpWhisper<cr>", desc = "Whisper", mode = "i" },
			{ "<C-g>R", "<cmd>GpWhisperRewrite<cr>", desc = "Whisper Inline Rewrite", mode = "i" },
			{ "<C-g>A", "<cmd>GpWhisperAppend<cr>", desc = "Whisper Append", mode = "i" },
			{ "<C-g>B", "<cmd>GpWhisperPrepend<cr>", desc = "Whisper Prepend", mode = "i" },
			{ "<C-g>E", "<cmd>GpWhisperEnew<cr>", desc = "Whisper Enew", mode = "i" },
			{ "<C-g>P", "<cmd>GpWhisperPopup<cr>", desc = "Whisper Popup", mode = "i" },
		},
		opts = {
			-- required openai api key
			openai_api_key = os.getenv("OPENAI_API_KEY"),
			-- api endpoint (you can change this to azure endpoint)
			openai_api_endpoint = "https://api.openai.com/v1/chat/completions",
			-- openai_api_endpoint = "https://$URL.openai.azure.com/openai/deployments/{{model}}/chat/completions?api-version=2023-03-15-preview",
			-- prefix for all commands
			cmd_prefix = "Gp",
			-- optional curl parameters (for proxy, etc.)
			-- curl_params = { "--proxy", "http://X.X.X.X:XXXX" }
			curl_params = {},

			-- directory for storing chat files
			chat_dir = vim.fn.expand("~") .. "/notes/ai_chat",
			-- chat model (string with model name or table with model name and parameters)
			chat_model = { model = "gpt-4", temperature = 1.1, top_p = 1 },
			-- chat_model = { model = "gpt-3.5-turbo-16k", temperature = 1.1, top_p = 1 },
			-- chat model system prompt (use this to specify the persona/role of the AI)
			chat_system_prompt = "You are a general AI assistant.",
			-- chat custom instructions (not visible in the chat but prepended to model prompt)
			chat_custom_instructions = "The user provided the additional info about how they would like you to respond:\n\n"
				.. "- If you're unsure don't guess and say you don't know instead.\n"
				.. "- Ask question if you need clarification to provide better answer.\n"
				.. "- Think deeply and carefully from first principles step by step.\n"
				.. "- Zoom out first to see the big picture and then zoom in to details.\n"
				.. "- Use Socratic method to improve your thinking and coding skills.\n"
				.. "- Don't elide any code from your output if the answer requires coding.\n"
				.. "- Take a deep breath; You've got this!\n",
			-- chat user prompt prefix
			chat_user_prefix = "🗨:",
			-- chat assistant prompt prefix
			chat_assistant_prefix = "💀:",
			-- chat topic generation prompt
			chat_topic_gen_prompt = "Summarize the topic of our conversation above"
				.. " in two or three words. Respond only with those words.",
			-- chat topic model (string with model name or table with model name and parameters)
			chat_topic_gen_model = "gpt-4",
			-- chat_topic_gen_model = "gpt-3.5-turbo-16k",
			-- explicitly confirm deletion of a chat file
			chat_confirm_delete = true,
			-- conceal model parameters in chat
			chat_conceal_model_params = true,
			-- local shortcuts bound to the chat buffer
			-- (be careful to choose something which will work across specified modes)
			chat_shortcut_respond = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g><C-g>" },
			chat_shortcut_delete = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>d" },
			chat_shortcut_new = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>n" },

			-- command config and templates bellow are used by commands like GpRewrite, GpEnew, etc.
			-- command prompt prefix for asking user for input
			command_prompt_prefix = "💀 ~ ",
			-- command model (string with model name or table with model name and parameters)
			command_model = { model = "gpt-4", temperature = 1.1, top_p = 1 },
			-- command_model = { model = "gpt-3.5-turbo-16k", temperature = 1.1, top_p = 1 },
			-- command system prompt
			command_system_prompt = "You are an AI that strictly generates just the formated final code.",

			-- templates
			template_selection = "I have the following code from {{filename}}:"
				.. "\n\n```{{filetype}}\n{{selection}}\n```\n\n{{command}}",
			template_rewrite = "I have the following code from {{filename}}:"
				.. "\n\n```{{filetype}}\n{{selection}}\n```\n\n{{command}}"
				.. "\n\nRespond just with the snippet of code that should be inserted.",
			template_append = "I have the following code from {{filename}}:"
				.. "\n\n```{{filetype}}\n{{selection}}\n```\n\n{{command}}"
				.. "\n\nRespond just with the snippet of code that should be appended after the code above.",
			template_prepend = "I have the following code from {{filename}}:"
				.. "\n\n```{{filetype}}\n{{selection}}\n```\n\n{{command}}"
				.. "\n\nRespond just with the snippet of code that should be prepended before the code above.",
			template_command = "{{command}}",

			-- https://platform.openai.com/docs/guides/speech-to-text/quickstart
			-- Whisper costs $0.006 / minute (rounded to the nearest second)
			-- by eliminating silence and speeding up the tempo of the recording
			-- we can reduce the cost by 50% or more and get the results faster
			-- directory for storing whisper files
			whisper_dir = "/tmp/gp_whisper",
			-- multiplier of RMS level dB for threshold used by sox to detect silence vs speech
			-- decibels are negative, the recording is normalized to -3dB =>
			-- increase this number to pick up more (weaker) sounds as possible speech
			-- decrease this number to pick up only louder sounds as possible speech
			-- you can disable silence trimming by setting this a very high number (like 1000.0)
			whisper_silence = "1.75",
			-- whisper max recording time (mm:ss)
			whisper_max_time = "05:00",
			-- whisper tempo (1.0 is normal speed)
			whisper_tempo = "1.75",

			-- example hook functions (see Extend functionality section in the README)
			hooks = {
				InspectPlugin = function(plugin, params)
					print(string.format("Plugin structure:\n%s", vim.inspect(plugin)))
					print(string.format("Command params:\n%s", vim.inspect(params)))
				end,

				-- GpImplement rewrites the provided selection/range based on comments in the code
				Implement = function(gp, params)
					local template = "Having following from {{filename}}:\n\n"
						.. "```{{filetype}}\n{{selection}}\n```\n\n"
						.. "Please rewrite this code according to the comment instructions."
						.. "\n\nRespond only with the snippet of finalized code:"

					gp.Prompt(
						params,
						gp.Target.rewrite,
						nil, -- command will run directly without any prompting for user input
						gp.config.command_model,
						template,
						gp.config.command_system_prompt
					)
				end,

				-- your own functions can go here, see README for more examples like
				-- :GpExplain, :GpUnitTests.., :GpBetterChatNew, ..
			},
		},
	},
}
