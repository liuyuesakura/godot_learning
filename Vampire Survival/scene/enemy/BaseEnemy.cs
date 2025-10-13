using Godot;
using System;
using VampireSurvival.script;


public partial class BaseEnemy: CharacterBody2D
{
    [Export] public float Speed { set; get; } = 500f;

    private AnimatedSprite2D AnimatedSprite { set; get; }
    private Node2D _body;

    public override void _Ready()
    {
        AnimatedSprite = GetNode<AnimatedSprite2D>("Body/AnimatedSprite2D");
        _body = GetNode<Node2D>("Body");
    }

    public override void _PhysicsProcess(double delta)
    {
        Velocity = GlobalPosition.DirectionTo(Game.Player.GlobalPosition) * Speed * (float)delta;
        
        // 执行移动
        MoveAndSlide();
        
        AnimePlay();
    }

    private void AnimePlay()
    {
        if(Velocity == Vector2.Zero)
            AnimatedSprite.Play("idle");
        else
        {
            AnimatedSprite.Play("walk");
        }

        if (Velocity.X < 0 && _body.Scale.X != -1)
        {
            _body.Scale = _body.Scale with { X = -1 };
        }
        else if (Velocity.X > 0 && _body.Scale.X != 1)
        {
            _body.Scale = _body.Scale with { X = 1 };
        }

    }
}
