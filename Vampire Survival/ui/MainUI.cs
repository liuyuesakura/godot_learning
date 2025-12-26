using Godot;
using System;
using VampireSurvival.script;

public partial class MainUI : Control
{
    [Export]
    public CanvasLayer UIRoot;
    private void _on_start_btn_pressed()
    {
        UIRoot.Hide();
        // we have already added main scene as bg so just send start signal and close mainui scene.
        //GetTree().ChangeSceneToFile("res://scene/main.tscn");
        Game.PlayerManager.EmitSignal(PlayerManager.SignalName.OnGameStart);
        
    }

    private void _on_exit_btn_pressed()
    {
        
    }
}
