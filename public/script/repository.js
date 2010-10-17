/* Repository */

// Create a repository
function Repository(repo_link, repo_name, chat, forks, creator, feed_items, parent, is_private)
{
  this.link = repo_link;
  this.name = repo_name;
  this.chat = chat;
  this.forks = forks;
  this.creator = creator;
  this.parent = parent;
  this.private = is_private;
  
  return this;
}

