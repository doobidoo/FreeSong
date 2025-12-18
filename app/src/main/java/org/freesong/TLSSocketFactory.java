package org.freesong;

import android.os.Build;
import android.util.Log;

import java.io.IOException;
import java.net.InetAddress;
import java.net.Socket;
import java.security.KeyManagementException;
import java.security.NoSuchAlgorithmException;

import javax.net.ssl.HttpsURLConnection;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;

/**
 * TLS 1.2 Socket Factory for Android 4.4 (API 19).
 *
 * Android 4.4 supports TLS 1.2 but doesn't enable it by default.
 * This factory forces TLS 1.2 to be used for HTTPS connections.
 */
public class TLSSocketFactory extends SSLSocketFactory {

    private static final String TAG = "TLSSocketFactory";
    private static final String[] TLS_PROTOCOLS = {"TLSv1.2", "TLSv1.1"};

    private SSLSocketFactory delegate;

    public TLSSocketFactory() throws NoSuchAlgorithmException, KeyManagementException {
        SSLContext context = SSLContext.getInstance("TLS");
        context.init(null, null, null);
        delegate = context.getSocketFactory();
    }

    /**
     * Enable TLS 1.2 globally for all HTTPS connections.
     * Call this once at app startup.
     */
    public static void enableTLS12() {
        if (Build.VERSION.SDK_INT >= 16 && Build.VERSION.SDK_INT < 20) {
            try {
                TLSSocketFactory factory = new TLSSocketFactory();
                HttpsURLConnection.setDefaultSSLSocketFactory(factory);
                Log.d(TAG, "TLS 1.2 enabled for Android " + Build.VERSION.SDK_INT);
            } catch (Exception e) {
                Log.e(TAG, "Failed to enable TLS 1.2", e);
            }
        }
    }

    @Override
    public String[] getDefaultCipherSuites() {
        return delegate.getDefaultCipherSuites();
    }

    @Override
    public String[] getSupportedCipherSuites() {
        return delegate.getSupportedCipherSuites();
    }

    @Override
    public Socket createSocket(Socket s, String host, int port, boolean autoClose) throws IOException {
        return enableTLSOnSocket(delegate.createSocket(s, host, port, autoClose));
    }

    @Override
    public Socket createSocket(String host, int port) throws IOException {
        return enableTLSOnSocket(delegate.createSocket(host, port));
    }

    @Override
    public Socket createSocket(String host, int port, InetAddress localHost, int localPort) throws IOException {
        return enableTLSOnSocket(delegate.createSocket(host, port, localHost, localPort));
    }

    @Override
    public Socket createSocket(InetAddress host, int port) throws IOException {
        return enableTLSOnSocket(delegate.createSocket(host, port));
    }

    @Override
    public Socket createSocket(InetAddress address, int port, InetAddress localAddress, int localPort) throws IOException {
        return enableTLSOnSocket(delegate.createSocket(address, port, localAddress, localPort));
    }

    private Socket enableTLSOnSocket(Socket socket) {
        if (socket instanceof SSLSocket) {
            ((SSLSocket) socket).setEnabledProtocols(TLS_PROTOCOLS);
        }
        return socket;
    }
}
