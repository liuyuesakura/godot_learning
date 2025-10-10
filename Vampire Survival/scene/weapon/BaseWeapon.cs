using Godot;
using System;

public partial class BaseWeapon : Node2D
{
    private Bullet Bullet;
    
    [Export]
    private Node2D BulletPoint;
    
    public override void _Ready()
    {
        Bullet = GD.Load<Bullet>("res://scene/bullet/BaseBullet.tscn");
        BulletPoint = GetNode<Node2D>("BulletPoint");
    }

    private void Shoot()
    {
        var instance = new Bullet();
        instance.GlobalPosition = BulletPoint.GlobalPosition;
        instance.LookAt( BulletPoint.GlobalPosition.DirectionTo(GetGlobalMousePosition()));
        instance.Direction = BulletPoint.GlobalPosition.DirectionTo(GetGlobalMousePosition());
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
