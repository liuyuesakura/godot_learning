using Godot;
using System;

public partial class BaseWeapon : Node2D
{
    private PackedScene Bullet;
    
    private Node2D _bulletPoint;
     
    public override void _Ready()
    {
        Bullet = GD.Load<PackedScene>("res://scene/bullet/BaseBullet.tscn");
        _bulletPoint = GetNode<Node2D>("BulletPoint");
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
        if (Input.IsActionJustPressed("fire"))
        {
            Shoot();
        }
    }
}
