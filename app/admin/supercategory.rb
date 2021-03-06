ActiveAdmin.register Supercategory do

  permit_params :list, :of, :attributes, :on, :model, :letter_code, :display_name, :instructions

  menu :priority => 3

  sidebar :status, :priority => 0 do
    mail_option_status
  end

  filter :display_name
  filter :letter_code
  filter :instructions
  filter :category

  index do
    column do |supercategory|
      ul do
        li link_to supercategory.display_name, admin_supercategory_path(supercategory.id)
        li do
          span "Category code:"
          span { link_to supercategory.letter_code, admin_supercategory_path(supercategory.id) }
        end
        li "Instructions - #{supercategory.instructions}"
        li "Number of categories: #{supercategory.categories.count}"
      end
    end
  end

  show do
    attributes_table do
      row :letter_code
      row :display_name
      row :instructions

      row "# Categories" do
        supercategory.categories.count
      end
    end

    panel "Categories For This Supercategory" do
      table_for(supercategory.categories.sort_by(&:code)) do |category|
        category.column("Code") { |item| item.code }
        category.column("Name") { |item| link_to item.name, admin_category_path(item.id) }
        category.column("Number of Articles") { |item| item.articles.count }
        category.column("Report Choices") { |item| report_choice_tags(item.report_choices) }
        category.column("Superjudge") do |item|
          link_to item.superjudge.name, admin_superjudge_path(item.superjudge.id) if item.superjudge
        end
      end
    end
  end

  form do |f|
    inputs "Details" do
      f.input :display_name
      f.input :letter_code
      f.input :instructions
      f.actions
    end
  end
end
