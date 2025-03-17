using System;
using Godot;

namespace VampireSurvival.script;

public partial class Player : CharacterBody2D
{
    [Export]
    public float MoveSpeed { get; set; } = 50.0f; // 可通过编辑器调整移动速度
    
    [Export] private AnimatedSprite2D _anim;
    [Export] private Node2D _body;

    public override void _Ready()
    {
        _anim ??= GetNode<AnimatedSprite2D>("Body/AnimatedSprite2D");
        _body ??= GetNode<Node2D>("Body");
    }
    
    // 记录面向方向的只读属性
    public Vector2 FacingDirection => _facingDirection;
    private Vector2 _facingDirection = Vector2.Down; // 默认面朝下方

    public override void _PhysicsProcess(double delta)
    {
        // 获取输入方向
        var inputDirection = GetInputDirection();
        // 仅在有输入时更新面向方向
        if (inputDirection != Vector2.Zero)
        {
            _facingDirection = inputDirection.Normalized();
        }

        // 更新速度
        Velocity = inputDirection * MoveSpeed;
        
        // 执行移动
        MoveAndSlide();
        //切换动画播放
        AnimPlay();
        QueueRedraw();
    }
    
    // 在_Process中绘制方向指示线
    public override void _Draw()
    {
        // GD.Print(_facingDirection);
        DrawLine(Vector2.Zero, _facingDirection * 50, Colors.Red, 2);
    }

    private Vector2 GetInputDirection()
    {
        // 获取原始输入向量
        Vector2 input = new Vector2(
            Input.GetActionStrength("move_right") - Input.GetActionStrength("move_left"),
            Input.GetActionStrength("move_down") - Input.GetActionStrength("move_up")
        );

        // 对斜向移动进行归一化处理
        return input.Normalized();
    }
    
    // 获取面向角度（弧度制）
    public float GetFacingAngle()
    {
        return _facingDirection.Angle();
    }

    // 获取四方向枚举示例（可根据项目需要扩展）
    public CardinalDirection GetCardinalDirection()
    {
        float angle = GetFacingAngle();
        return angle switch
        {
            > -Mathf.Pi/4 and <= Mathf.Pi/4 => CardinalDirection.Right,
            > Mathf.Pi/4 and <= 3*Mathf.Pi/4 => CardinalDirection.Down,
            > 3*Mathf.Pi/4 or <= -3*Mathf.Pi/4 => CardinalDirection.Left,
            _ => CardinalDirection.Up
        };
    }

    private void AnimPlay()
    {
        // 在动画脚本中根据方向切换动画
        switch (GetCardinalDirection())
        {
            case CardinalDirection.Left:
                _body.Scale = Vector2.Left + Vector2.Down;
                _anim.Play("lr_move");
                break;
            case CardinalDirection.Right:
                _body.Scale = Vector2.Right + Vector2.Down;
                _anim.Play("lr_move");
                break;
            case CardinalDirection.Up:
                _anim.Play("up_move");
                break;
            case CardinalDirection.Down:
                _anim.Play("down_move");
                break;
            default:
                break;
        }
    }
}

// 四方向枚举
public enum CardinalDirection
{
    Up,
    Down,
    Left,
    Right
}