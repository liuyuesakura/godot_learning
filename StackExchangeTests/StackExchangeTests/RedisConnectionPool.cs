using System.Threading;
using StackExchange.Redis;

public sealed class RedisConnectionPool : IDisposable
{
    private readonly object _syncRoot = new();
    private ConfigurationOptions _options;
    private ConnectionMultiplexer[] _connectionArray;
    private readonly int _poolSize;
    private int _index = -1;
    private bool _disposed;

    public RedisConnectionPool(string connectionString, int poolSize = 4)
        : this(ConfigurationOptions.Parse(connectionString), poolSize)
    {
    }

    public RedisConnectionPool(ConfigurationOptions options, int poolSize = 4)
    {
        if (poolSize <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(poolSize), "PoolSize must be greater than zero.");
        }

        _poolSize = poolSize;
        _options = CloneOptions(options);
        _connectionArray = CreateConnections(_options, _poolSize);
    }

    public IDatabase GetDatabase(int db = -1)
    {
        ThrowIfDisposed();
        var next = Interlocked.Increment(ref _index);
        var connection = _connectionArray[next % _connectionArray.Length];
        return connection.GetDatabase(db);
    }

    public void ForceReconnect()
    {
        ThrowIfDisposed();
        lock (_syncRoot)
        {
            var newConnections = CreateConnections(_options, _poolSize);
            SwapConnections(newConnections);
        }
    }

    public void Reconfigure(ConfigurationOptions options)
    {
        ThrowIfDisposed();
        lock (_syncRoot)
        {
            _options = CloneOptions(options);
            var newConnections = CreateConnections(_options, _poolSize);
            SwapConnections(newConnections);
        }
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        foreach (var connection in _connectionArray)
        {
            connection.Dispose();
        }
    }

    private void SwapConnections(ConnectionMultiplexer[] newConnections)
    {
        var oldConnections = _connectionArray;
        _connectionArray = newConnections;
        Interlocked.Exchange(ref _index, -1);

        foreach (var oldConnection in oldConnections)
        {
            oldConnection.Dispose();
        }
    }

    private static ConnectionMultiplexer[] CreateConnections(ConfigurationOptions options, int poolSize)
    {
        var array = new ConnectionMultiplexer[poolSize];
        for (var i = 0; i < poolSize; i++)
        {
            array[i] = ConnectionMultiplexer.Connect(CloneOptions(options));
        }

        return array;
    }

    private static ConfigurationOptions CloneOptions(ConfigurationOptions options) =>
        ConfigurationOptions.Parse(options.ToString());

    private void ThrowIfDisposed()
    {
        if (_disposed)
        {
            throw new ObjectDisposedException(nameof(RedisConnectionPool));
        }
    }
}
