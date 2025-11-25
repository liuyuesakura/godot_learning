using Godot;
using System;
using VampireSurvival.script;


public partial class BaseEnemy: CharacterBody2D
{
    [Export] public float Speed { set; get; } = 500f;

    private AnimatedSprite2D AnimatedSprite { set; get; }
    private Node2D _body;
    
    private PublicEnums.EnemyState _currentState = PublicEnums.EnemyState.Idle;
    private Node2D _currentAtkAim = null;

    public override void _Ready()
    {
        AnimatedSprite = GetNode<AnimatedSprite2D>("Body/AnimatedSprite2D");
        _body = GetNode<Node2D>("Body");
    }

    public override void _PhysicsProcess(double delta)
    {
        if (_currentState is not (PublicEnums.EnemyState.Death or
            PublicEnums.EnemyState.Atk))
        {
            Velocity = GlobalPosition.DirectionTo(Game.Player.GlobalPosition) * Speed * (float)delta;

            // 执行移动
            MoveAndSlide();

            AnimePlay();
        }
        
        DoScale();
    }

    private void AnimePlay()
    {
        if (Velocity == Vector2.Zero)
        {
            AnimatedSprite.Play("idle");
            _currentState = PublicEnums.EnemyState.Idle; 
        }
        else
        {
            AnimatedSprite.Play("walk");
            _currentState = PublicEnums.EnemyState.Walk;
        }
    }

    /// <summary>
    /// 处理玩家在敌人左右时的翻转
    /// 这里的翻转不会打断动画 ！！！
    /// </summary>
    private void DoScale()
    {
        var vector2 = GlobalPosition.DirectionTo(Game.Player.GlobalPosition);
        _body.Scale = vector2.X switch
        {
            < 0 when !Mathf.IsEqualApprox(_body.Scale.X, -1) => _body.Scale with { X = -1 },
            > 0 when !Mathf.IsEqualApprox(_body.Scale.X, 1) => _body.Scale with { X = 1 },
            _ => _body.Scale
        };
    }
    
    private void _on_atk_area_body_entered(Node2D body)
    {
        if (body is Player)
        {
            _currentState = PublicEnums.EnemyState.Atk;
            _currentAtkAim = body;
            // GD.Print("hi");
            AnimatedSprite.Play("atk");
        }
    }

    private void _on_atk_area_body_exited(Node2D body)
    {
        GD.Print("leave");
        if (_currentState == PublicEnums.EnemyState.Atk 
            && _currentAtkAim == body)
        {
            _currentState = PublicEnums.EnemyState.Idle;
            _currentAtkAim = null;
            AnimatedSprite.Play("idle");  
        }
    }

    private void _on_animated_sprite_2d_animation_changed()
    {
        if (_currentState == PublicEnums.EnemyState.Atk &&
            AnimatedSprite.Animation == "atk")
        {
            if (_currentAtkAim != null && AnimatedSprite.Frame == 2)
            {
                // 造成伤害
            }
        } 
    }

    private void _on_animated_sprite_2d_animation_finished()
    {
        if (_currentState == PublicEnums.EnemyState.Atk &&
            AnimatedSprite.Animation == "atk")
        {
            if (_currentAtkAim == null) // 玩家离开攻击范围
            {
                AnimatedSprite.Play("idle");
            }
            else
            {
                AnimatedSprite.Play("atk");
            }
        } 
    }

    private void _on_animated_sprite_2d_frame_changed()
    {
        if (AnimatedSprite.Animation == "atk")
        {
            GD.Print(AnimatedSprite.Frame);
        }
    }
}
