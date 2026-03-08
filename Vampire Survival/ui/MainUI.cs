using Godot;
using System;
using VampireSurvival.script;

namespace VampireSurvival.UI;

public partial class MainUI : Control
{
    [Export] public CanvasLayer UiRoot; // Renamed to PascalCase as per warning

    public override void _Ready()
    {
        
    }
    
    private void _on_start_btn_pressed()
    {
        var tween = UiRoot.CreateTween();
        tween.TweenProperty(UiRoot.GetChild(0), "modulate:a", 0.0f, 0.3f);
        tween.TweenCallback(Callable.From(TweenCallback));
        // UIRoot.Hide();
        // we have already added main scene as bg so just send start signal and close mainui scene.
        //GetTree().ChangeSceneToFile("res://scene/main.tscn"); // directly jump to scene.
        Game.PlayerManager.EmitSignal(PlayerManager.SignalName.OnGameStart);
        Game.LevelManager.SwitchToLevel(1234);
        // Game.LevelManager.EmitSignal(LevelManager.SignalName.OnLevelChanged, Game.LevelManager.CurrentLevel);
    }

    private void TweenCallback()
    {
        // UiRoot.Hide();
    }

    private void _on_exit_btn_pressed()
    {
        GetTree().Quit();
    }
}
