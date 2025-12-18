using Godot;

namespace VampireSurvival.script;

public partial class PlayerManager : Node
{
	// C# convention uses PascalCase for properties.
	public PlayerData PlayerData { get; private set; }

	private static PackedScene _pistol;

	// 1. Define signals using delegates with the [Signal] attribute.
	//    C# naming conventions prefer PascalCase for signals and events.
	[Signal]
	public delegate void OnPlayerHpChangedEventHandler(int current, int max);

	[Signal]
	public delegate void OnPlayerDeathEventHandler();

	// _ready() becomes _Ready() in C#
	public override void _Ready()
	{
		_pistol = GD.Load<PackedScene>("res://scene/weapon/Pistol.tscn");
		// 2. Instantiate the C# class.
		PlayerData = new PlayerData(this);
		PlayerData.CurrentHp = PlayerData.MaxHp;
		Game.PlayerManager = this;

		this.OnMagazineReloadStarted += () =>
		{
			var t = new Timer();
			AddChild(t);
			t.WaitTime = 2;
			t.OneShot = true;
			t.Timeout += () =>
			{
				EmitSignal(PlayerManager.SignalName.OnMagazineReloadFinished);
				if (!IsInstanceValid(t)) 
					return;
				t.QueueFree();
				t = null;
			};
			t.Start();
		};
	}

	// _process(delta) becomes _Process(double delta)
	public override void _Process(double delta)
	{
		// The 'pass' keyword is not needed in C#.
	}

	public override void _Input(InputEvent @event)
	{
		if (@event.IsActionPressed("ui_accept"))
		{
			ChangeWeapon(_pistol.Instantiate<BaseWeapon>());
		}
	}

	public bool IsDeath() => PlayerData.CurrentHp <= 0;

	public void ChangeWeapon(BaseWeapon newWeapon)
	{
		var currentWeapon = Game.Player.WeaponNode.GetChild(0);
		currentWeapon?.QueueFree();
		Game.Player.WeaponNode.AddChild(newWeapon);
	}
	
	[Signal]
	public delegate void OnBulletCountChangedEventHandler(int current, int max);
	
	[Signal]
	public delegate void OnMagazineReloadStartedEventHandler();

	[Signal]
	public delegate void OnMagazineReloadFinishedEventHandler();

	[Signal]
	public delegate void OnWeaponChangedEventHandler(BaseWeapon weapon);
}
