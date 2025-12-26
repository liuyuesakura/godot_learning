using Godot;
using VampireSurvival.script;

namespace VampireSurvival.scene;

public partial class Main : Node2D
{

    [Export] public PackedScene PlayerPrefab;
    
    [Export]
    public CanvasLayer CanvasLayer;
    
    public override void _Ready()
    {
        Game.PlayerManager.OnGameStart += () =>
        {
            CanvasLayer.Show();
            Game.Player = PlayerPrefab.Instantiate<Player>();
        };
    }
}