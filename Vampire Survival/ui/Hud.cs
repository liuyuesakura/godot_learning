using Godot;
using System;
using VampireSurvival.script;

public partial class Hud : Control
{
    private ProgressBar HpBar { set; get; }
    private Label MagazineLabel { set; get; }
    
    public override void _Ready()
    {
        HpBar = GetNode<ProgressBar>("HpHUD/HpBar");
        HpBar.Value = Game.Player.PlayerData.CurrentHp;
        HpBar.MaxValue = Game.Player.PlayerData.MaxHp;

        Game.PlayerManager.OnPlayerHpChanged += PlayerHpChangedOnHud;
        
        MagazineLabel = GetNode<Label>("WeaponHUD/Magazine");
        Game.PlayerManager.OnBulletCountChanged += BulletCountChangedOnHud;
        Game.PlayerManager.OnMagazineReloadStarted += MagazineReloadStartedOnHud;
        Game.PlayerManager.OnMagazineReloadFinished += MagazineReloadFinishedOnHud;
    }

    private void MagazineReloadFinishedOnHud()
    {
        //pass
    }

    private void MagazineReloadStartedOnHud()
    {
        MagazineLabel.Text = "Reloading...";
    }

    private void BulletCountChangedOnHud(int current, int max)
    {
        MagazineLabel.Text = $"{current}/{max}";
    }

    private void PlayerHpChangedOnHud(int current, int max)
    {
        HpBar.Value = current;
    }
}
