package org.freesong;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.ProgressDialog;
import android.content.DialogInterface;
import android.os.AsyncTask;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/**
 * Activity for configuring GitHub sync settings.
 */
public class GitHubSettingsActivity extends Activity {

    private EditText tokenInput;
    private EditText repoInput;
    private Button testBtn;
    private Button saveBtn;
    private Button clearBtn;
    private Button backBtn;
    private Button themeBtn;
    private TextView lastSyncText;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        ThemeManager.applyTheme(this);
        setContentView(R.layout.activity_github_settings);

        tokenInput = (EditText) findViewById(R.id.tokenInput);
        repoInput = (EditText) findViewById(R.id.repoInput);
        testBtn = (Button) findViewById(R.id.testBtn);
        saveBtn = (Button) findViewById(R.id.saveBtn);
        clearBtn = (Button) findViewById(R.id.clearBtn);
        backBtn = (Button) findViewById(R.id.backBtn);
        themeBtn = (Button) findViewById(R.id.themeBtn);
        lastSyncText = (TextView) findViewById(R.id.lastSyncText);

        // Load existing config
        loadConfig();
        updateThemeButton();
        updateLastSyncText();

        backBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                finish();
            }
        });

        themeBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                toggleTheme();
            }
        });

        testBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                testConnection();
            }
        });

        saveBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                saveConfig();
            }
        });

        clearBtn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                confirmClearConfig();
            }
        });
    }

    private void toggleTheme() {
        ThemeManager.toggleDarkMode(this);
        recreate();
    }

    private void updateThemeButton() {
        if (ThemeManager.isDarkMode(this)) {
            themeBtn.setText(R.string.theme_icon_sun);
        } else {
            themeBtn.setText(R.string.theme_icon_moon);
        }
    }

    private void loadConfig() {
        String token = GitHubConfig.getToken(this);
        String repo = GitHubConfig.getRepo(this);

        if (token != null && !token.isEmpty()) {
            tokenInput.setText(token);
        }
        if (repo != null && !repo.isEmpty()) {
            repoInput.setText(repo);
        }
    }

    private void updateLastSyncText() {
        long lastSync = GitHubConfig.getLastSync(this);
        if (lastSync > 0) {
            SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault());
            String dateStr = sdf.format(new Date(lastSync));
            lastSyncText.setText(getString(R.string.github_last_sync, dateStr));
        } else {
            lastSyncText.setText(R.string.github_never_synced);
        }
    }

    private void testConnection() {
        final String token = tokenInput.getText().toString().trim();
        final String repo = repoInput.getText().toString().trim();

        if (token.isEmpty()) {
            Toast.makeText(this, R.string.github_token_required, Toast.LENGTH_SHORT).show();
            return;
        }

        if (repo.isEmpty()) {
            Toast.makeText(this, R.string.github_repo_required, Toast.LENGTH_SHORT).show();
            return;
        }

        if (!repo.contains("/")) {
            Toast.makeText(this, R.string.github_repo_format, Toast.LENGTH_SHORT).show();
            return;
        }

        new TestConnectionTask(token, repo).execute();
    }

    private class TestConnectionTask extends AsyncTask<Void, Void, GitHubApiClient.ApiResponse> {
        private ProgressDialog dialog;
        private String token;
        private String repo;

        TestConnectionTask(String token, String repo) {
            this.token = token;
            this.repo = repo;
        }

        @Override
        protected void onPreExecute() {
            dialog = new ProgressDialog(GitHubSettingsActivity.this);
            dialog.setMessage(getString(R.string.github_testing));
            dialog.setCancelable(false);
            dialog.show();
        }

        @Override
        protected GitHubApiClient.ApiResponse doInBackground(Void... params) {
            GitHubApiClient api = new GitHubApiClient(token, repo);
            return api.testConnection();
        }

        @Override
        protected void onPostExecute(GitHubApiClient.ApiResponse response) {
            if (dialog != null && dialog.isShowing()) {
                dialog.dismiss();
            }

            if (response.success) {
                Toast.makeText(GitHubSettingsActivity.this,
                    R.string.github_connection_success, Toast.LENGTH_SHORT).show();
            } else {
                String msg = getString(R.string.github_connection_failed) + ": " + response.errorMessage;
                Toast.makeText(GitHubSettingsActivity.this, msg, Toast.LENGTH_LONG).show();
            }
        }
    }

    private void saveConfig() {
        String token = tokenInput.getText().toString().trim();
        String repo = repoInput.getText().toString().trim();

        if (token.isEmpty()) {
            Toast.makeText(this, R.string.github_token_required, Toast.LENGTH_SHORT).show();
            return;
        }

        if (repo.isEmpty()) {
            Toast.makeText(this, R.string.github_repo_required, Toast.LENGTH_SHORT).show();
            return;
        }

        if (!repo.contains("/")) {
            Toast.makeText(this, R.string.github_repo_format, Toast.LENGTH_SHORT).show();
            return;
        }

        GitHubConfig.setToken(this, token);
        GitHubConfig.setRepo(this, repo);

        Toast.makeText(this, R.string.github_config_saved, Toast.LENGTH_SHORT).show();
        setResult(RESULT_OK);
        finish();
    }

    private void confirmClearConfig() {
        new AlertDialog.Builder(this)
            .setTitle(R.string.github_clear_title)
            .setMessage(R.string.github_clear_message)
            .setPositiveButton(R.string.clear, new DialogInterface.OnClickListener() {
                @Override
                public void onClick(DialogInterface dialog, int which) {
                    clearConfig();
                }
            })
            .setNegativeButton(R.string.cancel, null)
            .show();
    }

    private void clearConfig() {
        GitHubConfig.clearConfig(this);
        tokenInput.setText("");
        repoInput.setText("");
        updateLastSyncText();
        Toast.makeText(this, R.string.github_config_cleared, Toast.LENGTH_SHORT).show();
    }
}
