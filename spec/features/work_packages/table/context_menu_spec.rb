require 'spec_helper'

describe 'Work package table context menu', js: true do
  let(:user) { FactoryBot.create(:admin) }
  let(:work_package) { FactoryBot.create(:work_package) }

  let(:wp_table) { Pages::WorkPackagesTable.new }
  let(:wp_timeline) { Pages::WorkPackagesTimeline.new(work_package.project) }
  let(:menu) { Components::WorkPackages::ContextMenu.new }
  let(:destroy_modal) { Components::WorkPackages::DestroyModal.new }
  let(:display_representation) { ::Components::WorkPackages::DisplayRepresentation.new }

  def goto_context_menu list_view = true
    # Go to table
    wp_table.visit!
    wp_table.expect_work_package_listed(work_package)

    display_representation.switch_to_card_layout unless list_view
    loading_indicator_saveguard

    # Open context menu
    menu.expect_closed
    menu.open_for(work_package, list_view)
  end

  shared_examples_for 'provides a context menu' do
    let(:list_view) { raise 'needs to be defined' }

    context 'for a single work package' do
      it 'provide a context menu' do
        # Open detail pane
        goto_context_menu list_view
        menu.choose('Open details view')
        split_page = Pages::SplitWorkPackage.new(work_package)
        split_page.expect_attributes Subject: work_package.subject

        # Open full view
        goto_context_menu list_view
        menu.choose('Open fullscreen view')
        expect(page).to have_selector('.work-packages--show-view .wp-edit-field.subject',
                                      text: work_package.subject)

        # Open log time
        goto_context_menu list_view
        menu.choose('Log time')
        expect(page).to have_selector('h2', text: I18n.t(:label_spent_time))

        # Open Move
        goto_context_menu list_view
        menu.choose('Move')
        expect(page).to have_selector('h2', text: I18n.t(:button_move))
        expect(page).to have_selector('a.issue', text: "##{work_package.id}")

        # Open Copy
        goto_context_menu list_view
        menu.choose('Copy')
        # Split view open in copy state
        expect(page).
          to have_selector('.wp-new-top-row',
                           text: "#{work_package.status.name.capitalize}\n#{work_package.type.name.upcase}")
        expect(page).to have_field('wp-new-inline-edit--field-subject', with: work_package.subject)

        # Open Delete
        goto_context_menu list_view
        menu.choose('Delete')
        destroy_modal.expect_listed(work_package)
        destroy_modal.cancel_deletion

        # Open create new child
        goto_context_menu list_view
        menu.choose('Create new child')
        expect(page).to have_selector('.wp-edit-field.subject input')
        expect(page).to have_selector('.wp-inline-edit--field.type')

        find('#work-packages--edit-actions-cancel').click
        expect(page).to have_no_selector('.wp-edit-field.subject input')

        # Timeline actions only shown when open
        wp_timeline.expect_timeline!(open: false)

        goto_context_menu list_view
        menu.expect_no_options 'Add predecessor', 'Add follower'
      end
    end

    context 'for multiple selected WPs' do
      let!(:work_package2) { FactoryBot.create(:work_package) }

      it 'provides a context menu with a subset of the available menu items' do
        # Go to table
        wp_table.visit!
        wp_table.expect_work_package_listed(work_package)
        wp_table.expect_work_package_listed(work_package2)

        display_representation.switch_to_card_layout unless list_view
        loading_indicator_saveguard

        # Select all WPs
        find('body').send_keys [:control, 'a']

        menu.open_for(work_package, list_view)
        menu.expect_options ['Open details view', 'Open fullscreen view',
                             'Bulk edit', 'Bulk copy', 'Bulk move', 'Bulk delete']
      end
    end
  end

  before do
    login_as(user)
    work_package
  end

  context 'in the table' do
    it_behaves_like 'provides a context menu' do
      let(:list_view) { true }
    end

    it 'provides a context menu with timeline options' do
      goto_context_menu true
      # Open timeline
      wp_timeline.toggle_timeline
      wp_timeline.expect_timeline!(open: true)

      # Open context menu
      menu.expect_closed
      menu.open_for(work_package)
      menu.expect_options ['Add predecessor', 'Add follower']
    end
  end

  context 'in the card view' do
    it_behaves_like 'provides a context menu' do
      let(:list_view) { false }
    end
  end
end
