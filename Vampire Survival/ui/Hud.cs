using Godot;
using System;
using VampireSurvival.script;

namespace VampireSurvival.UI;

public partial class Hud : Control
{
    private ProgressBar HpBar { set; get; }
    private Label MagazineLabel { set; get; }
    
    private Label WeaponName  { set; get; }
    
    private TextureRect WeaponTexture  { set; get; }
    
    public override void _Ready()
    {
        HpBar = GetNode<ProgressBar>("HpHUD/HpBar");
        //HpBar.Value = Game.Player.PlayerData.CurrentHp; // make sure the loading chain is robust.
        // HpBar.MaxValue = Game.Player.PlayerData.MaxHp; 

        Game.PlayerManager.OnPlayerHpChanged += PlayerHpChangedOnHud;
        
        MagazineLabel = GetNode<Label>("WeaponHUD/Magazine");
        WeaponName = GetNode<Label>("WeaponHUD/WeaponName");
        WeaponTexture = GetNode<TextureRect>("WeaponHUD/TextureRect");
        Game.PlayerManager.OnBulletCountChanged += BulletCountChangedOnHud;
        Game.PlayerManager.OnMagazineReloadStarted += MagazineReloadStartedOnHud;
        Game.PlayerManager.OnMagazineReloadFinished += MagazineReloadFinishedOnHud;
        Game.PlayerManager.OnWeaponChanged += weapon =>
        {
            WeaponName.Text = weapon.WeaponName;
            WeaponTexture.Texture = weapon.WeaponSprite.Texture;
            BulletCountChangedOnHud(weapon.MagazineCurrentCount, weapon.MagazineMaxSize);
        };
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
