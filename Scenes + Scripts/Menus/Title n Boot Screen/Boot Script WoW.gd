#Boot Script WoW.gd (Boot Script World Of Wonders)
extends Control

@onready var fade_rect: ColorRect = $Fades/FadeRect
@onready var fade: AnimationPlayer = $Fades/Fade

const TITLE_SCREEN_PATH = "res://Scenes + Scripts/Menus/Title n Boot Screen/Title Screen.tscn"

var potato

var InputReady = false
var rng = RandomNumberGenerator.new()
const names = [
	"World O' Wonders",
	"Wonders O' World",
	"Wonders: Also Try Terraria.. Maybe Even Minecraft!",
	"Wonders: Bunni Power",
	
	#Generated Randomly
	"Wonders: Now With 200% More RNG!", #5
	"Wonders: This Title Was Procedurally Generated",
	"Wonders: Warning: Bats Are Still Annoying",
	"Wonders: Slimes Were Harmed in the Making of This Game",
	"Wonders: Generating 10,000 Sand Blocks… Done!",
	"Wonders: Achievement Unlocked: You Opened the Game!", #10
	"Wonders: Boss Music Intensifies",
	"Wonders: A Meteor Has Landed… Somewhere",
	"Wonders: That’s Not a Glitch, It’s a Feature!",
	"Wonders: You Tried to Summon a Boss, Didn’t You?",
	"Wonders: This Game Contains 100% More Wonder", #15 Choices
	"Wonders: No Refunds, No Regrets",
	"Wonders: Because Who Needs Sleep?",
	"Wonders: Now in *Stunning* 2D!",
	"Wonders: Your Adventure Begins… Now! Wait, Now!",
	"Wonders: Batteries Not Included", #20
	"Wonders: The RTX May Be Too True To Be Real...", #I added this 1
	"Wonders: Guaranteed to Make You Smile (No Refunds)",
	"Wonders: Do NOT Fall Down The Rabbit Hole!",
	"Wonders: Batteries Not Included",  
	"Wonders: Powered by Hope and Duct Taped Code",  #25
	"Wonders: Not Liable for Any Explosions",  
	"Wonders: Objects in Motion Stay in Motion Unless Collided With",  # - NEWton Slimster - 2025 
	"Wonders: Insert Catchy Slogan Here",  
	"Wonders: No, You Can't Pet the Slimes",  #(I didnt tell it I had slimes?)
	"Wonders: Built Different™",  #BRO THIS IS RANDOMLY GENERATED HOWW     #30
	"Wonders: Breaking the Fourth Wall Since Forever",  #Yup 
	"Wonders: Everything is Under Control… Probably",  
	"Wonders: An Adventure of Infinite Possibilities!",  
	"Wonders: Contains 100% Real Pixels",  
	"Wonders: Physics? Never Heard of It",  #35
	"Wonders: Now With More Colors Than Ever Before!",  #FR
	"Wonders: The Cake Is… Oh, Wait. Wrong Game",  #Portal? Why
	"Wonders: This Title Took Hours to Think Of",  #Perfection Right Here
	"Wonders: You’re Gonna Like This One, Trust Me",  
	"Wonders: Gravity Works… Most of the Time", #Proceeds To Fall        #40
	"Wonders: Behold, The Power of Code!",
	"Wonders: Because Nothing Else Matters Right Now",
	"Wonders: Do Not Taunt the Menu Screen",  
	"Wonders: Warning: May Contain Surprises",  
	"Wonders: Featuring 87% More Shenanigans!",  #45
	"Wonders: This Game is Legally a Game",  
	"Wonders: Running on Pure Imagination",  
	"Wonders: Somewhere, a Programmer is Crying",  #LMAO WHAT
	"Wonders: Slightly More Polished Than Yesterday",  
	"Wonders: Guaranteed to Contain Pixels",  #50
	"Wonders: Don’t Worry, We Checked the Code (Once)",  
	"Wonders: The Fun is Non-Refundable",  #Actually Funny
	"Wonders: No Wrong Choices… Just Bad Ones",  
	"Wonders: Featuring Over 3 Lines of Code!", #Actually Funny
	"Wonders: Why Are You Still Reading This?",  #55
	"Wonders: We Were Supposed to Fix That Bug…",  
	"Wonders: It’s Dangerous to Go Alone, Take This!",  
	"Wonders: Behold, The Wonders of the Digital World!",   
	"Wonders: Danger! Excitement! And Bunnies!",  
	"Wonders: Certified Pixelated Excellence",  #60
	"Wonders: No Dragons, Just Vibes",  #This One Seems Personal.. Mystic??
	"Wonders: The Wait is Over… Until the Next Update",  
	"Wonders: Fully Compatible with Your Imagination",  
	"Wonders: Sometimes, It’s About the Journey",  
	"Wonders: Why Walk When You Can Roll?",  #50
	"Wonders: Because Life Needs More Wonders!",  
	"Wonders: No Save Points? No Problem!",  
	"Wonders: Crafted With Passion, Fueled by Chaos",  
	"Wonders: Who Put This Here?",  
	"Wonders: Any Bugs Are Just… Features",  #55
	"Wonders: Don't Question It, Just Play!",  
	"Wonders: If You’re Reading This, You’re Awesome!",  
	"Wonders: A Masterpiece of Button Pressing!",  
	"Wonders: Certified for Maximum Enjoyment!",  
	"Wonders: What Could Possibly Go Wrong?",  #60
	"Wonders: The Wonders Never End!",  
	
	"Wonders: Now Featuring Dynamic Shadows! (Maybe)",  
	"Wonders: Our Artists Worked Hard—Please Appreciate",  
	"Wonders: 60 FPS? More Like 60 Feelings Per Second!",
	"Wonders - Rev 2: Because 1 Revision Wasn't Enough",  #65
	"Wonders: Now With A New Bunny!",
	"Wonders: We Updated The Splash Screen!!!"
] 
"""^^^ Open To See List Of Names For Game"""
var chosenname = "EmptySTRING"
var chance_weight = 21  # Set the weight of "World O' Wonders Name To Be Selected More" (default is 21, 25% chance). 3 Was old default, aka 4.55% chance
#Each of the 64 names have a 1.19% chance to be selected

func _ready():
	if Global.is_demo:
		$"Camera2D/CanvasLayer/Title Parallax/DEMO".show()
	
	print_rich("[color=orange]################Boot Script WoW###############")

	if not (OS.get_name() == "Android" or OS.get_name() == "iOS"):
		#Use custom script to change discord stats
		DiscordStatusHandler.update_details_and_state("On Bootup Screen", "Prob Listening To That Sick Music")
		DiscordStatusHandler.update_small_image("title_screen", "What A Nice Boot Screen..")
	
	AudioServer.set_bus_volume_db(0, 0)
	fade_rect.show()
	fade.play("Fade_Title_In")
	
	rng.randomize()
	var weighted_names = []
	@warning_ignore("shadowed_variable_base_class")
	for name in names:
		if name == "World O' Wonders":
			for i in range(chance_weight):
				weighted_names.append(name) #Giving it at chance i select basically
		else:
			weighted_names.append(name) #Else it just does the names as normal with a 1.19% chance
	
	# Choose a name randomly from the weighted array
	var no = rng.randi_range(0, weighted_names.size() - 1)
	chosenname = weighted_names[no]
	print("RNG No: ", no, " | Which is Name: ", chosenname)
	if Global.is_demo:
		chosenname = "Wonders: DEMO"
	DisplayServer.window_set_title(chosenname)


func _allow_change_scene():
	InputReady = true
	if $Camera2D/StartGame:
		$Camera2D/StartGame.show()
	print_rich("[color=green]Change Scene Allowed")

func _input(event):
	if InputReady:
		if event is InputEventScreenTouch && event.is_pressed():
			print("Game Started Via Tap")
			_start_game()
		
		
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
				print("Game Started Via Left Mouse Button")
				_start_game()
		
		
		if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("Jump") or Input.is_action_just_pressed("Pause"):
			print("Game Started Via Keyboard / Mouse")
			_start_game()
	
	
	
	if Input.is_action_just_pressed("Graphics_Quality"):
		if $WorldEnvironment:
			potato = !potato
			if potato:
				print("Disabled World Environment")
				$WorldEnvironment.environment = null
			else:
				print("Enabled World Environment")
				$WorldEnvironment.environment = load("res://Environments/Boot Screen WoW Environment.tres")
		else:
			print_rich("[color=red]Global: WARNING - No Environment Found As Child Of Root")

func _start_game():
	self.queue_free()
	get_tree().change_scene_to_file(TITLE_SCREEN_PATH)
