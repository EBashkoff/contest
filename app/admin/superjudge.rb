ActiveAdmin.register Superjudge do

  permit_params :list, :of, :attributes, :on, :model, :name, :email, :sent_mail,
                :sent_mail_time, :choice, :choice_comment, :must_choose

  menu :priority => 6

  scope("All") { |scope| scope.all }
  scope("Mail Sent") { |scope| scope.where(:sent_mail => true) }
  scope("Mail Not Sent") { |scope| scope.where(:sent_mail => nil) }

  scope("Voted?") do |scope|
    Superjudge.where(:id => scope.select { |superjudge| superjudge.votes_in? == "Yes" }.map(&:id))
  end

  scope("Not Voted?") do |scope|
    Superjudge.where(:id => scope.select { |superjudge| superjudge.votes_in? == "No" }.map(&:id))
  end

  sidebar :status, :only => :index, :priority => 0 do
    mail_option_status
  end

  filter :articles
  filter :categories, :as => :select, :collection => Category.all.sort_by(&:name)
  filter :name
  filter :email
  filter :sent_mail
  filter :sent_mail_time

  index do

    column :name do |superjudge|
      link_to superjudge.name, admin_superjudge_path(superjudge.id)
    end

    column "E-Mail Address", :email
    column :sent_mail
    column :sent_mail_time

    column "# Categories" do |superjudge|
      superjudge.categories.count
    end

    column "# Articles" do |superjudge|
      superjudge.all_articles.count
    end

    column "Voted?" do |superjudge|
      status_tag superjudge.votes_in?
    end

    actions :defaults => false do |superjudge|
      link_to "Send Mail", send_mail_admin_superjudge_path(superjudge), class: "member_link"
    end

    actions :defaults => false do |judge|
      link_to "Vote", vote_admin_superjudge_path(judge), class: "member_link"
    end
  end

  member_action :send_mail, :method => :get do
    resource.send_mail!
    redirect_to resource_path, notice: "Mail Sent!"
  end

  member_action :vote, :method => :get do
    @superjudge = resource
    @superjudge.vote!
  end

  member_action :record_vote, :method => :post do
  end

  member_action :recalculate, :method => :post do
    @superjudge = resource
    @superjudge.recalculate!
  end

  controller do
    def send_mail
      set_superjudge
      if @superjudge.all_articles.count { |article_info| article_info[:article].final == "MAIL" } > 0
        Timeout::timeout(10) do
          JudgeMailer.superjudge_notification(*set_mail_to_superpeople, @superjudge).deliver_now
        end
        if Setting.first.mail_option
          @superjudge.update_attributes(:sent_mail => true, :sent_mail_time => Time.now)
          @superjudge.save
        end
        flash[:notice] = "Mail Sent Successfully!"
      else
        flash[:error] = "There are no articles to vote on for #{@superjudge.name} - No mailing sent"
      end
    rescue
      flash[:error] = "Mail NOT Sent Successfully!"
    ensure
      redirect_to admin_superjudges_path
    end

    def vote
      set_superjudge
      if @superjudge.categories.count < 1 || @superjudge.articles_to_vote_for.count < 1
        flash[:error] = "#{@superjudge.name} either has no categories or no articles to vote for"
        redirect_to admin_superjudges_path
        return
      end

      @details = @superjudge.articles_to_vote_for.group_by(&:category)
      @m       = {}
      @details.each do |category, articles|
        @m.merge!({ category.name => {} })
        @m[category.name][:must_choose_number] = 5 - category.articles.where(:final => "WINNER").count
        articles.each do |article|
          @m[category.name][article.id] = { :choice => article.final == "WINNER_BY_CHOICE" ? "checked" : nil }
          @m[category.name][article.id].merge!({ :choice_comment => article.superjudge_comment })
        end
      end
      puts @m
    end

    def record_vote
      if params[:commit] == "cancel"
        redirect_to admin_superjudges_path
        return
      end

      set_superjudge
      failure = false

      @superjudge.articles_to_vote_for.group_by(&:category).each do |category, articles|
        must_choose = params[:must_choose][category.name]

        number_chosen = if params[:choice] && params[:choice][category.name]
                          articles.count do |article|
                            params[:choice][category.name][article.id.to_s]
                          end
                        else
                          0
                        end

        articles.each do |article|
          article.final              = params[:choice][category.name][article.id.to_s] ? "WINNER_BY_CHOICE" : "RUNNER_UP"
          article.superjudge_comment = params[:choice_comment][category.name][article.id.to_s]
          article.save
        end if params[:choice] && params[:choice][category.name]

        failure = true if number_chosen != must_choose.to_i
      end

      if failure
        flash[:error] = "The wrong number of articles was selected for one of the given categories"
        redirect_to vote_admin_superjudge_path(@superjudge)
        return
      end

      redirect_to admin_superjudge_path(@superjudge)
    end

    def recalculate
      set_superjudge
      @superjudge.calculate_judge_mailings(:force_recalculation => true )
      redirect_to admin_superjudge_path(@superjudge)
    end

  end

  action_item :mail, :only => :show do
    link_to "Send Mail", send_mail_admin_superjudge_path(resource)
  end

  action_item :vote, :only => :show do
    link_to "Vote", vote_admin_superjudge_path(resource)
  end

  show do
    panel "Mailings Status" do
      mail_option_status
    end

    attributes_table do
      row :name
      row :email

      row :sent_mail do
        status_tag :sent_mail
      end

      row :sent_mail_time

      row :votes_in? do
        status_tag superjudge.votes_in?
      end

      row "# Categories" do
        superjudge.categories.count
      end

      row "# Articles" do
        superjudge.all_articles.count
      end
    end

    panel "Categories for Superjudge #{resource.name}" do
      table_for(superjudge.categories.sort_by(&:code)) do |category|
        category.column("Code") { |item| item.code }
        category.column("Name") { |item| link_to item.name, admin_category_path(item.id) }
        category.column("Number of Articles") { |item| item.articles.map(&:any_choice_article?).compact.count }
        category.column("Report Choices") { |item| report_choice_tags(item.report_choices) }
      end
    end

    panel "Articles Under Consideration for Superjudge #{resource.name}" do
      render :partial => 'recalculate'
      article_list = resource.calculate_judge_mailings.sort_by do |a|
        a[:article].category.code + a[:award_level].to_s
      end
      table_for(article_list) do |article_info|
        article_info.column("Phase 1") do |item|
          show_prize_level(item[:article])
        end
        article_info.column("Phase 2") do |item|
          show_final_level(item[:article])
        end
        article_info.column("Code") { |item| item[:article].code }
        article_info.column("Title") { |item|
          div do
            div link_to item[:article].pretty_title, admin_article_path(item[:article].id)
            if (m = item[:article].any_choice_article?)
              jc = m.comment_for(item[:article].id).presence
              li "Judge comment: #{jc}", :style => "width: 600px;" if jc
              sjc = item[:article].superjudge_comment.presence
              li "Superjudge comment: #{sjc}", :style => "width: 600px;" if sjc
            end
          end
        }
        article_info.column("Judge") do |item|
          link_to item[:article].judge.name, admin_judge_path(item[:article].judge)
        end
      end
    end
  end

  form do |f|
    inputs 'Details' do
      f.input :name
      f.input :email
    end
    f.actions
  end

end

private

def set_superjudge
  @superjudge = Superjudge.find(params[:id])
end

def set_mail_to_superpeople
  if Setting.first.mail_option
    [@superjudge.name, @superjudge.email]
  else
    [Setting.first.default_person, Setting.first.default_email]
  end
end

