using Godot;
using System;
using VampireSurvival.script;

public partial class BaseWeapon : Node2D
{
    private PackedScene Bullet;
    
    private Node2D _bulletPoint;

    [Export]
    public int MagazineMaxSize { set; get; } = 30;
    
    public int MagazineCurrentCount { set; get; }

    [Export] public double RofBase { set; get; } = 0.2; // Rate of fire
    private double _rofTick = 0;
    private bool _reloadLock = false;
    
    public double RofCurrent { set; get; }

    [Export]
    public int BulletDamage { set; get; } = 10;

    [Export]
    public string WeaponName { set; get; } = "Base";
    
    [Export]
    public Sprite2D WeaponSprite  { set; get; }
     
    public override void _Ready()
    {
        Bullet = GD.Load<PackedScene>("res://scene/bullet/BaseBullet.tscn");
        _bulletPoint = GetNode<Node2D>("BulletPoint");

        MagazineCurrentCount = MagazineMaxSize;
        RofCurrent = RofBase;
        _rofTick = RofCurrent;
        Game.PlayerManager.OnMagazineReloadStarted += () =>
        {
            _reloadLock = true;
        };
        
        Game.PlayerManager.OnMagazineReloadFinished += () =>
        {
            _reloadLock = false;
            MagazineCurrentCount = MagazineMaxSize;
            Game.PlayerManager.EmitSignal(PlayerManager.SignalName.OnBulletCountChanged, MagazineCurrentCount,
                MagazineMaxSize);
        };
        Game.PlayerManager.EmitSignal(PlayerManager.SignalName.OnWeaponChanged, this);
    }

    private void Shoot()
    {
        var instance = Bullet.Instantiate<Node2D>();
        instance.GlobalPosition = _bulletPoint.GlobalPosition;
        instance.LookAt( _bulletPoint.GlobalPosition.DirectionTo(GetGlobalMousePosition()));
        //instance = BulletPoint.GlobalPosition.DirectionTo(GetGlobalMousePosition());
        GetTree().Root.AddChild(instance);
    }

    public override void _Process(double delta)
    {
        _rofTick += _reloadLock?0:delta;
        if (Input.IsActionJustPressed("fire") && _rofTick >= RofCurrent && MagazineCurrentCount > 0 && !_reloadLock)
        {
            Shoot();
            _rofTick = 0;
            MagazineCurrentCount -= 1;
            Game.PlayerManager.EmitSignal(PlayerManager.SignalName.OnBulletCountChanged, MagazineCurrentCount,
                MagazineMaxSize);
        }

        if (MagazineCurrentCount <= 0 && !_reloadLock)
        {
            Reload();
        }

    }

    public void Reload() 
    {
        // play sound effect
        // add sound effect finished signal ,then we can shoot.
        Game.PlayerManager.EmitSignal(PlayerManager.SignalName.OnMagazineReloadStarted);
    }


}
