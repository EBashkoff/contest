ActiveAdmin.register Article do

  permit_params :list, :of, :attributes, :on, :model, :title, :link, :index,
                :judge_id, :category_id, :update_judge_id, :publisher_id

  menu :priority => 5

  scope("All") { |scope| scope.all }
  scope("Articles Assigned") { |scope| scope.where("JUDGE_ID IS NOT NULL") }
  scope("Articles Not Assigned") { |scope| scope.where("JUDGE_ID IS NULL") }

  scope("Phase 1 Chosen") do |scope|
    Article.where(:id => scope.select { |article| article.any_choice_article? }.map(&:id))
  end

  scope("Phase 2 Chosen") do |scope|
    Article.where(:id => scope.select { |article| %w(WINNER WINNER_BY_CHOICE RUNNER_UP MAIL).include?(article.final) }.map(&:id))
  end

  scope("Phase 2 Winners") do |scope|
    Article.where(:id => scope.select { |article| %w(WINNER WINNER_BY_CHOICE).include?(article.final) }.map(&:id))
  end

  sidebar :status, :priority => 0 do
    mail_option_status
  end

  filter :judge, :as => :select, :collection => Judge.all.sort_by(&:name)
  filter :category, :as => :select, :collection => Category.all.sort_by(&:name)
  filter :title, :label => "Article"
  filter :publisher

  index do
    render :partial => 'sidebar_toggler'

    column :category, sortable: 'categories.name' do |article|
      div link_to article.code, admin_category_path(article.category_id)
      category_id = article.category_id
      div link_to Category.find(category_id).name, admin_category_path(category_id)
    end

    column :article do |article|
      link_to article.pretty_title, admin_article_path(article.id)
    end

    column "Judge/Superjudge", :sortable => 'judges.name' do |article|
      judge_id = article.judge_id
      judge    = Judge.find(judge_id) if judge_id
      div do
        span "J: "
        span link_to judge.name, admin_judge_path(judge.id)
      end if judge
      superjudge = article.superjudge
      div do
        span "S: "
        span link_to superjudge.name, admin_superjudge_path(superjudge)
      end if superjudge
    end

    column :phase_1 do |article|
      show_prize_level(article)
    end

    column :phase_2 do |article|
      show_final_level(article)
    end

    column :publisher do |article|
      article.publisher.name
    end

  end

  csv do
    column :code do |article|
      article.code
    end

    column :category do |article|
      category_id = article.category_id
      Category.find(category_id).name
    end

    column :article do |article|
      article.pretty_title
    end

    column :link

    column :judge do |article|
      judge_id = article.judge_id
      judge    = Judge.find(judge_id) if judge_id
      judge.name if judge
    end

    column :phase_1 do |article|
      show_prize_level_string(article)
    end

    column :judge_comment do |article|
      article.comment
    end

    column :superjudge do |article|
      article.superjudge.try(:name)
    end

    column :phase_2 do |article|
      show_final_level_string(article)
    end

    column :superjudge_comment

    column :publisher do |article|
      article.publisher.name
    end

    column :publisher_code_number do |article|
      article.publisher.code_number
    end
  end

  member_action :edit_judge, :method => :get

  member_action :update_judge, :method => :post

  controller do
    def scoped_collection
      super.includes :category, :judge # prevents N+1 queries to your database
    end

    def create
      article = Article.new
      if article.update_attributes(permitted_params[:article])
        flash[:notice] = "Successfully created new article"
        redirect_to edit_judge_admin_article_path(article)
      else
        flash[:error] = "Could not save new article"
        redirect_to admin_articles_path
      end
    end

    def edit_judge
      set_article
      @judges = @article.category.judges
    end

    def update_judge
      set_article
      if params[:commit] == "submit"
        if @article.update_attributes(:judge_id => params[:update_judge_id])
          flash[:notice] = "Successfully added judge #{@article.judge.name} to this article"
          redirect_to admin_article_path(@article)
        else
          flash[:error] = "Could not save article with this judge correctly"
          redirect_to admin_articles_path
        end
      else
        @article.destroy
        redirect_to admin_articles_path
      end
    end
  end

  show :title => :pretty_title do

    attributes_table do
      row :phase_1 do |article|
        show_prize_level(article)
      end

      row :phase_2 do |article|
        show_final_level(article).presence || status_tag(:not_chosen)
      end

      row :code

      row :category do |article|
        category_id = article.category_id
        c           = Category.find(category_id) if category_id
        link_to c.name, admin_category_path(category_id) if c
      end

      row :pretty_title

      row :publisher do |article|
        article.publisher.name
      end

      row :raw_title do |article|
        article.title
      end

      row :link do |article|
        link_to article.link, article.link, :target => "_blank"
      end

      row :judge do |article|
        judge_id = article.judge_id
        j        = Judge.find(judge_id) if judge_id
        link_to j.name, admin_judge_path(judge_id) if j
      end

      if resource.any_choice_article? && resource.comment.present?
        row :judge_comment do |article|
          article.comment
        end
      end

      row :superjudge if resource.superjudge

      if resource.superjudge_comment.present?
        row :superjudge_comment do |article|
          article.superjudge_comment
        end
      end
    end
  end

  form do |f|
    if f.object.new_record?
      inputs "Details for this new article" do
        f.input :title
        f.input :link
        f.input :publisher
        f.input :category, :include_blank => false
      end
    else
      inputs "Details for this article in category #{resource.category.name}" do
        f.input :title
        f.input :link
      end

      inputs 'Use this section to reassign this article to another judge' do
        if resource.a_first_choice_article? || resource.a_second_choice_article?
          li "WARNING: This article has already been selected as a first or second choice favorite by judge #{resource.judge.name}. Be sure to resubmit votes for this judge.", :style => "color: red;"
        end
        f.input :judge, :collection => resource.category.mappings.map(&:judge).map { |j| [j.name, j.id] }, :include_blank => false
      end
    end
    f.actions
  end

end

private

def set_article
  @article = Article.find(params[:id])
end

