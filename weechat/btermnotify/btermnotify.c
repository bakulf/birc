/* btermnotify.c - a plugin for weechat
 * Copyright (C) 2015 Andrea Marchesini
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>
#include <stdlib.h>

#include <weechat/weechat-plugin.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <glib.h>

WEECHAT_PLUGIN_NAME("BtermNotify")
WEECHAT_PLUGIN_AUTHOR("Andrea Marchesini")
WEECHAT_PLUGIN_DESCRIPTION("Notification using bterm")
WEECHAT_PLUGIN_VERSION(PVERSION)
WEECHAT_PLUGIN_LICENSE("GPL3")

struct t_weechat_plugin *weechat_plugin = NULL;

void bterm_notify(GString* message)
{
  int sockfd, servlen;
  struct sockaddr_un  serv_addr;
  int done = 0;

  memset(&serv_addr,0x0, sizeof(serv_addr));
  serv_addr.sun_family = AF_UNIX;

  strcpy(serv_addr.sun_path, "/tmp/bterm.socket");
  servlen = strlen(serv_addr.sun_path) + sizeof(serv_addr.sun_family);

  if ((sockfd = socket(AF_UNIX, SOCK_STREAM,0)) < 0) {
    printf("Error connecting with the socket!");
  }

  if (connect(sockfd, (struct sockaddr *) &serv_addr, servlen) < 0) {
    printf("Error connecting with the socket (2)!");
  }

  while (done < message->len) {
    int ret = write(sockfd, message->str + done, message->len - done);
    if (ret <= 0) {
      break;
    }

    done += ret;
  }

  close(sockfd);
}

int online_cb(char *word[], char *word_eol[], void *userdata)
{
  GString* str = g_string_new(NULL);
  g_string_printf(str, "%s is online", word[4]);
  bterm_notify(str);
  g_string_free(str, TRUE);
  return XCHAT_EAT_NONE;
}

int offline_cb(char *word[], char *word_eol[], void *userdata)
{
  GString* str = g_string_new(NULL);
  g_string_printf(str, "%s is offline", word[4]);
  bterm_notify(str);
  g_string_free(str, TRUE);
  return XCHAT_EAT_NONE;
}

int privmsg_cb(char *word[], char *word_eol[], void *userdata)
{
  xchat_plugin* ph = (xchat_plugin*)userdata;

  GString* str = g_string_new(NULL);
  GString* nick = g_string_new(NULL);
  const char *currentNick;
  int i = 0;

  if (xchat_get_prefs (ph, "irc_nick1", &currentNick, NULL) != 1 ||
      strcmp(word[3], currentNick)) {
    return XCHAT_EAT_NONE;
  }

  if (word[1][0] == ':') {
    ++i;
  }

  while(word[1][i] && word[1][i] != '!') {
    g_string_append_c(nick, word[1][i++]);
  }

  g_string_printf(str, "%s is talking", nick->str);
  bterm_notify(str);

  g_string_free(nick, TRUE);
  g_string_free(str, TRUE);
  return XCHAT_EAT_NONE;
}

int weechat_plugin_init (struct t_weechat_plugin *plugin,
                         int argc, char *argv[])
{
  weechat_plugin = plugin;

  weechat_hook_signal("irc_notify_join" online_cb, NULL);
  weechat_hook_signal("irc_notify_quit" offline_cb, NULL);

  xchat_hook_server(plugin_handle, "PRIVMSG", XCHAT_PRI_NORM, privmsg_cb,
                    plugin_handle);

  return WEECHAT_RC_OK;
}

int weechat_plugin_end (struct t_weechat_plugin *plugin)
{
  return WEECHAT_RC_OK;
}
