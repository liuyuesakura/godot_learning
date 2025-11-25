using Godot;

namespace VampireSurvival.script;

public partial class PlayerManager : Node
{
	// C# convention uses PascalCase for properties.
	public PlayerData PlayerData { get; private set; }

	// 1. Define signals using delegates with the [Signal] attribute.
	//    C# naming conventions prefer PascalCase for signals and events.
	[Signal]
	public delegate void OnPlayerHpChangedEventHandler(int current, int max);

	[Signal]
	public delegate void OnPlayerDeathEventHandler();

	// _ready() becomes _Ready() in C#
	public override void _Ready()
	{
		// 2. Instantiate the C# class.
		PlayerData = new PlayerData(this);
		PlayerData.CurrentHp = PlayerData.MaxHp;
		Game.PlayerManager = this;
	}

	// _process(delta) becomes _Process(double delta)
	public override void _Process(double delta)
	{
		// The 'pass' keyword is not needed in C#.
	}
	
	public bool IsDeath() => PlayerData.CurrentHp <= 0;
}
