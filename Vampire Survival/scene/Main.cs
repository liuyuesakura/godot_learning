using System;
using Godot;
using VampireSurvival.script;

namespace VampireSurvival.scene;

public partial class Main : Node2D
{

    [Obsolete]
    [Export] public PackedScene PlayerPrefab;
    
    [Export]
    public CanvasLayer CanvasLayer;
    
    public override void _Ready()
    {
        Game.PlayerManager.OnGameStart += () =>
        {
            CanvasLayer.Show();
            // CreateTween().TweenProperty(CanvasLayer.GetChild<Control>(0), "modulate:a", 255, 1).From(0);
            
            AddChild(Game.PlayerManager.PlayerScene.Instantiate<Player>());
            // PlayerPrefab.Instantiate<Player>();
        };
    }
}