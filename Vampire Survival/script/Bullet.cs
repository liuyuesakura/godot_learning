using Godot;
using System;

public partial class Bullet : Node2D
{
    [Export]
    public float Speed { get; set; } = 500.0f; // 可通过编辑器调整移动速度
    
    [Export]
    public Vector2 Direction { get; set; } = Vector2.Zero;

    public override void _PhysicsProcess(double delta)
    {
        Position = Direction * (float)delta * Speed;
        
        base._PhysicsProcess(delta);
    }
}
