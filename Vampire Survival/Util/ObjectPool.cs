using System.Collections.Generic;
using Godot;

namespace VampireSurvival.Util;

// T must be a Node2D (or Node3D/Node depending on your needs)

public class ObjectPool<T> where T : Node2D
{
    private readonly PackedScene _scene;
    private readonly Node _parent;
    private readonly Queue<T> _availableObjects = new();

    // Constructor
    public ObjectPool(PackedScene scene, Node parent, int initialSize = 10)
    {
        _scene = scene;
        _parent = parent;

        // "Pre-warm" the pool by creating objects immediately
        for (int i = 0; i < initialSize; i++)
        {
            var obj = CreateNew();
            ReturnToPool(obj);
        }
    }

    private T CreateNew()
    {
        var obj = _scene.Instantiate<T>();
        _parent.AddChild(obj); // Add to scene tree immediately
        return obj;
    }

    public T Get()
    {
        var obj = _availableObjects.Count > 0 ? 
            _availableObjects.Dequeue() :
            // Pool is empty, create a new one (expandable pool)
            CreateNew();

        // Re-enable the object
        obj.Visible = true;
        obj.SetProcess(true);
        obj.SetPhysicsProcess(true);
        
        return obj;
    }

    public void ReturnToPool(T obj)
    {
        // Disable the object so it doesn't eat CPU/Physics
        obj.Visible = false;
        obj.SetProcess(false);
        obj.SetPhysicsProcess(false);
        
        // Reset position to avoid visual glitches next time it appears
        obj.GlobalPosition = Vector2.Zero; 

        _availableObjects.Enqueue(obj);
    }
}