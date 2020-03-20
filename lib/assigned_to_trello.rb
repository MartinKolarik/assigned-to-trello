require 'trello'
require 'octokit'
require 'rest_client'
require 'memoist'

Trello::Card.extend Memoist
Trello::Card.memoize :attachments

# Creates cards on a Trello board any time you're assigned an issue on GitHub.
class AssignedToTrello
  extend Memoist
  extend Forwardable

  def_delegator :board, :cards
  def_delegator :octokit, :issues
  memoize :cards
  memoize :issues

  def octokit
    Octokit::Client.new(access_token: ENV['GITHUB_TOKEN'])
  end
  memoize :octokit

  def board
    Trello::Board.find ENV['TRELLO_BOARD_ID']
  end
  memoize :board

  def list
    board.lists.find { |l| l.name == ENV['TRELLO_LIST_NAME'] }
  end
  memoize :list

  def member
    Trello::Member.find(ENV['TRELLO_MEMBER'])
  end
  memoize :member

  def find_card_by_issue(issue)
    cards.find do |card|
      card.attachments.any? do |attachment|
        attachment.url == issue.html_url
      end
    end
  end

  def create_card_from_issue(issue)
    Trello.logger.debug "Creating card for #{issue.title}"
    card = Trello::Card.create(name: issue.title, list_id: list.id)
    card.add_attachment issue.html_url, issue.html_url
    card.add_member member
    card
  end

  def run
    Trello.logger.debug "Found #{issues.count} issues assigned"
    issues.each do |issue|
      next if issue.title =~ /^Nagios/
      next if find_card_by_issue(issue)
      next if ENV['IGNORE_REPO_OWNERS'] and ENV['IGNORE_REPO_OWNERS'].split(',').include? issue.repository.owner.login
      create_card_from_issue(issue)
    end
  end
end
