# Catalog/Search Pages Navigation Component Rendering

## Overview
Catalog and search pages in WVU Knapsack use a multi-layered view resolution system that loads navigation components through theme-aware view paths. The navigation is rendered via masthead and controls partials, with theme-specific overrides possible at multiple levels.

---

## 1. Controller Files

### Main Controllers
- **[hyrax-webapp/app/controllers/catalog_controller.rb](hyrax-webapp/app/controllers/catalog_controller.rb)** - Primary Blacklight catalog controller
  - Includes `Hydra::Catalog` and other Hyrax behaviors
  - No layout override specified, uses default `hyrax.html.erb` layout
  - Blacklight configuration for search, faceting, and display

- **[app/controllers/catalog_controller_decorator.rb](app/controllers/catalog_controller_decorator.rb)** - WVU Knapsack customizations
  - Configures Blacklight advanced search
  - Hides the generic_type_sim facet from sidebar (Hyku #3072 workaround)
  - Minimal configuration - does NOT inject theme views dynamically

---

## 2. Layout Files & Rendering Chain

### Default Layout (Used by Catalog Pages)
**[hyrax-webapp/app/views/layouts/hyrax.html.erb](hyrax-webapp/app/views/layouts/hyrax.html.erb#L1)**
```erb
<!-- add body classes to make styling easier -->
<!DOCTYPE html>
<html lang="<%= I18n.locale.to_s %>" prefix="og:http://ogp.me/ns#">
  <head>
    <%= render partial: 'layouts/head_tag_content' %>
    <%= content_for(:head) %>
  </head>
  <% content_for(:extra_body_classes, 'public-facing') unless params[:controller].match(/^proprietor/) %>
  <% content_for(:extra_body_classes, ' search-only') if current_account && current_account.search_only %>

  <body class="<%= body_class %> <%= home_page_theme %> <%= search_results_theme %> <%= show_page_theme %>">
    <%= render_gtm_body(request.original_url) %>
    <div class="skip-to-content">
      <%= link_to "Skip to Content", "#skip-to-content" %>
    </div>
    <%= render '/masthead', placement_class: nil %>     <!-- ← NAVIGATION MASTHEAD -->
    <%= content_for(:navbar) %>
    <%= content_for(:precontainer_content) %>
    <div id="content-wrapper" class="container" role="main">
      <%= render '/flash_msg' %>
      <%= render_breadcrumbs builder: Hyrax.config.breadcrumb_builder %>
      <% if content_for?(:page_header) %>
        <div class="row">
          <div class="col-12 main-header">
            <%= yield(:page_header) %>
          </div>
        </div>
      <% end %>
      <a name="skip-to-content" id="skip-to-content"></a>
      <%= render 'shared/read_only' if Flipflop.read_only? %>
      <%= content_for?(:content) ? yield(:content) : yield %>
    </div><!-- /#content-wrapper -->
    <% if controller.controller_name == 'splash' || controller.controller_name == 'homepage' %>
      <%= render 'shared/footer' %>
    <% end %>
    <%= render 'shared/modal' %>
  </body>
</html>
```

### Theme-Specific Layouts
All theme layouts inherit from the same pattern and render the same masthead:

- **[app/views/themes/wvu_home/layouts/hyrax.html.erb](app/views/themes/wvu_home/layouts/hyrax.html.erb)**
- **[hyrax-webapp/app/views/themes/institutional_repository/layouts/hyrax.html.erb](hyrax-webapp/app/views/themes/institutional_repository/layouts/hyrax.html.erb)**
- **[hyrax-webapp/app/views/themes/cultural_repository/layouts/hyrax.html.erb](hyrax-webapp/app/views/themes/cultural_repository/layouts/hyrax.html.erb)**

Each includes: `<%= render '/masthead', placement_class: nil %>`

---

## 3. Masthead & Controls Components

### Default Masthead (Used When No Theme Override Exists)
**[hyrax-webapp/app/views/_masthead.html.erb](hyrax-webapp/app/views/_masthead.html.erb)**

```erb
<%# OVERRIDE Hyrax v5.2.0 to render either admin or user util links %>

<header aria-label="header" class="top-header">
  <nav id="masthead" class="navbar navbar-expand-lg navbar-dark bg-dark justify-content-between <%= placement_class %>" role="navigation" aria-label="masthead">
    <h1 class="sr-only"><%= application_name %></h1>
    <%= render '/logo' %>
    <button class="navbar-toggler" type="button" data-toggle="collapse" data-target="#top-navbar-collapse" aria-expanded="false" aria-label="Toggle navigation">
      <span class="navbar-toggler-icon"></span>
    </button>
    <div class="collapse navbar-collapse justify-content-end" id="top-navbar-collapse">
      <% if admin_host? %>
        <%= render '/admin_util_links' %>    <!-- ← Admin navigation links -->
      <% else %>
        <%= render '/user_util_links' %>     <!-- ← User navigation links -->
      <% end %>
    </div>
  </nav>
</header>
```

### Theme-Specific Masthead Examples

#### Institutional Repository Theme
**[hyrax-webapp/app/views/themes/institutional_repository/_masthead.html.erb](hyrax-webapp/app/views/themes/institutional_repository/_masthead.html.erb)**

```erb
<% # OVERRIDE: Hyrax v5.0.0rc2 - added the search bar and removed the /login and locale nav menu and moved to the /controls partial for theming %>
<header aria-label="header" class="top-header">
  <nav id="masthead" class="navbar navbar-expand-lg navbar-dark bg-dark institutional-repository-nav container-fluid d-block py-2<%= placement_class %>" role="navigation" aria-label="masthead">

    <div class="row align-items-center">
      <div class="col-lg-6 col-md-5 col-sm-12">
        <div class="row justify-content-start">
          <div class="ml-2"><%= render '/logo' %>
            <span class="institutional-repository-application-name"><%= application_name %></span>
          </div>
        </div>
      </div>
      <div class="col-lg-6 col-md-7 col-sm-12">
        <%= render partial: 'catalog/search_form' %>    <!-- ← Search form in masthead -->
      </div>
    </div>
  </nav>
</header>
<%= render '/controls' %>    <!-- ← Secondary navigation/controls -->
```

#### WVU Home Theme
**[app/views/themes/wvu_home/layouts/hyrax.html.erb](app/views/themes/wvu_home/layouts/hyrax.html.erb)** - No custom _masthead file
- Falls back to default masthead from hyrax-webapp
- Has custom _controls partial for navigation

#### Community Theme
**[hyrax-webapp/app/views/themes/community/_masthead.html.erb](hyrax-webapp/app/views/themes/community/_masthead.html.erb)**
```erb
<header aria-label="header" class="community-header">
  <nav id="masthead" class="navbar navbar-expand-lg navbar-dark bg-dark community-masthead">
    <div class="container-fluid">
      <%= render '/logo' %>
      <button class="navbar-toggler" type="button" data-toggle="collapse" data-target="#community-navbar-collapse" aria-expanded="false" aria-label="Toggle navigation">
        <span class="navbar-toggler-icon"></span>
      </button>
      <div class="collapse navbar-collapse" id="community-navbar-collapse">
        <ul class="navbar-nav mx-auto">
          <li><%= link_to 'Home', hyrax.root_path, class: 'nav-link px-3' %></li>
          <li><%= link_to 'About', hyrax.about_path, class: 'nav-link px-3' %></li>
          <li><%= link_to 'Help', hyrax.help_path, class: 'nav-link px-3' %></li>
          <li><%= link_to 'Contact', hyrax.contact_path, class: 'nav-link px-3' %></li>
        </ul>
        <hr class="bg-light d-lg-none">
        <%= render '/user_util_links' %>
      </div>
    </div>
  </nav>
</header>
```

### Controls Partials

#### WVU Home Controls
**[app/views/themes/wvu_home/_controls.html.erb](app/views/themes/wvu_home/_controls.html.erb)**
```erb
<% # OVERRIDE: Hyrax - Remove Help link (issue #13) and update Contact to LibAnswers (issue #14) %>
<nav class="navbar bg-light navbar-expand-sm justify-content-between align-items-center px-2 py-3 border-bottom" role="navigation" aria-label="Root Menu">
    <ul class="nav navbar-nav col-sm-5">
      <li class="nav-item <%= 'active font-weight-bold' if current_page?(hyrax.root_path) %>">
        <%= link_to t(:'hyrax.controls.home'), hyrax.root_path, class: "nav-link", aria: current_page?(hyrax.root_path) ? {current: 'page'} : nil %></li>
      <li class="nav-item <%= 'active font-weight-bold' if current_page?(hyrax.about_path) %>">
        <%= link_to t(:'hyrax.controls.about'), hyrax.about_path, class: "nav-link", aria: current_page?(hyrax.about_path) ? {current: 'page'} : nil %></li>
      <li class="nav-item">
        <%= link_to t(:'hyrax.controls.contact'), 'https://westvirginia.libanswers.com/wvrhc', class: "nav-link", target: '_blank', rel: 'noopener noreferrer' %></li>
    </ul><!-- /.nav -->
    <div class="col-sm-7">
      <%= render partial: 'catalog/search_form' %>
    </div>
  </nav><!-- /.navbar -->
```

#### Institutional Repository Controls
**[hyrax-webapp/app/views/themes/institutional_repository/_controls.html.erb](hyrax-webapp/app/views/themes/institutional_repository/_controls.html.erb)**
```erb
<% # OVERRIDE: Hyrax v5.0.0rc2 - added the admin login menu from _user_util_links partial for theming %>
<nav class="navbar navbar-light bg-light navbar-expand-sm justify-content-between align-items-center px-2 py-3 border-bottom flex-wrap" role="navigation" aria-label="Root Menu">
  <ul class="navbar-nav col-sm-5">
    <li class="nav-item <%= 'active' if current_page?(hyrax.root_path) %>">
      <%= link_to t(:'hyrax.controls.home'), hyrax.root_path, class: "nav-link", aria: current_page?(hyrax.root_path) ? {current: 'page'} : nil %></li>
    <li class="nav-item <%= 'active' if current_page?(hyrax.about_path) %>">
      <%= link_to t(:'hyrax.controls.about'), hyrax.about_path, class: "nav-link", aria: current_page?(hyrax.about_path) ? {current: 'page'} : nil %></li>
    <li class="nav-item <%= 'active' if current_page?(hyrax.help_path) %>">
      <%= link_to t(:'hyrax.controls.help'), hyrax.help_path, class: "nav-link", aria: current_page?(hyrax.help_path) ? {current: 'page'} : nil %></li>
    <li class="nav-item <%= 'active' if current_page?(hyrax.contact_path) %>">
      <%= link_to t(:'hyrax.controls.contact'), hyrax.contact_path, class: "nav-link", aria: current_page?(hyrax.contact_path) ? {current: 'page'} : nil %></li>
  </ul><!-- /.nav -->
  <%# OVERRIDE begin -->
  <% if admin_host? %>
    <%= render '/admin_util_links' %>
  <% else %>
    <%= render '/user_util_links' %>
  <% end %>
  <%# OVERRIDE end -->
</nav><!-- /.navbar -->
```

### User/Admin Utility Links

#### Default User Utility Links
**[hyrax-webapp/app/views/_user_util_links.html.erb](hyrax-webapp/app/views/_user_util_links.html.erb)**
- Locale picker (if multiple translations)
- Notifications
- User dropdown menu (name, dashboard link, logout, etc.)
- Sign-in link (if not logged in)

#### Theme-Specific User Utility Links
- **[app/views/themes/wvu_home/_user_util_links.html.erb](app/views/themes/wvu_home/_user_util_links.html.erb)** - Same as default
- **[hyrax-webapp/app/views/themes/cultural_repository/_user_util_links.html.erb](hyrax-webapp/app/views/themes/cultural_repository/_user_util_links.html.erb)** - Custom styling for cultural repository theme

#### Admin Utility Links
**[hyrax-webapp/app/views/_admin_util_links.html.erb](hyrax-webapp/app/views/_admin_util_links.html.erb)** - Admin-specific navigation (not currently shown in catalog pages)

---

## 4. View Path Resolution for Non-Homepage Routes

### Global View Path Setup
**[lib/hyku_knapsack/engine.rb](lib/hyku_knapsack/engine.rb)** (lines 80-110)

All controllers have their view paths prepended with the Knapsack engine views:
```ruby
# In ApplicationController and all descendants:
paths = [HykuKnapsack::Engine.root.join('app', 'views').to_s] + original_paths
```

This means the view resolution order for catalog pages is:
1. `wvu_knapsack/app/views/` ← Knapsack customizations (highest priority)
2. `hyrax-webapp/app/views/` ← Hyrax default views
3. Gem-provided views

### Theme-Specific View Resolution
**[hyrax-webapp/app/controllers/concerns/hyku/home_page_themes_behavior.rb](hyrax-webapp/app/controllers/concerns/hyku/home_page_themes_behavior.rb)**

Only applies to homepage and page controllers with `inject_theme_views` around_action:
```ruby
def inject_theme_views
  if home_page_theme && home_page_theme != 'default_home'
    original_paths = view_paths
    Hyku::Application.theme_view_path_roots.each do |root|
      home_theme_view_path = File.join(root, 'app', 'views', "themes", home_page_theme.to_s)
      prepend_view_path(home_theme_view_path)
    end
    yield
    view_paths=(original_paths)
  else
    yield
  end
end
```

### Catalog Pages & Theme Views
**⚠️ IMPORTANT: Catalog controller does NOT have theme-specific view path injection**

For catalog/search pages:
- They use the default `hyrax.html.erb` layout (not a theme-specific layout)
- Theme-specific _masthead files ARE found and used because they exist in the theme folder
- But this happens through the static global view path setup, not dynamic theme switching
- The `_controls` partial is also theme-aware through the same mechanism

**View resolution for rendering `/masthead` in catalog pages:**
1. `wvu_knapsack/app/views/themes/[current_theme]/_masthead.html.erb` (if exists)
2. `wvu_knapsack/app/views/_masthead.html.erb` (if exists)
3. `hyrax-webapp/app/views/themes/[current_theme]/_masthead.html.erb` (if exists)
4. `hyrax-webapp/app/views/_masthead.html.erb` ← Default fallback

---

## 5. Theme Structure

### Available Themes
- `wvu_home` - WVU-specific customizations
- `institutional_repository` - IR template
- `community` - Community theme
- `cultural_repository` - Cultural repository variant
- `neutral_repository` - Neutral repository variant
- And others...

### Theme File Organization

Each theme can override:
- `layouts/hyrax.html.erb` - Main layout
- `layouts/homepage.html.erb` - Homepage layout
- `_masthead.html.erb` - Header navigation
- `_controls.html.erb` - Secondary navigation
- `_user_util_links.html.erb` - User links
- `catalog/_search_form.html.erb` - Search form in header

**Example Structure:**
```
app/views/themes/wvu_home/
├── _controls.html.erb
├── _facets.html.erb
├── _home_text.html.erb
├── _user_util_links.html.erb
├── catalog/
│   └── _search_form.html.erb
├── hyrax/
│   └── ...work-type-specific views
└── layouts/
    ├── homepage.html.erb
    └── hyrax.html.erb

hyrax-webapp/app/views/themes/institutional_repository/
├── _masthead.html.erb
├── _controls.html.erb
├── _user_util_links.html.erb
├── catalog/
│   └── _search_form.html.erb
├── layouts/
│   ├── homepage.html.erb
│   └── hyrax.html.erb
└── ...
```

---

## 6. Search Form Rendering in Catalog Pages

The search form appears in the masthead (for some themes):

**[app/views/themes/wvu_home/catalog/_search_form.html.erb](app/views/themes/wvu_home/catalog/_search_form.html.erb)**
**[hyrax-webapp/app/views/themes/institutional_repository/catalog/_search_form.html.erb](hyrax-webapp/app/views/themes/institutional_repository/catalog/_search_form.html.erb)**

Rendered via:
```erb
<%= render partial: 'catalog/search_form' %>
```

The default search form location:
**[hyrax-webapp/app/views/catalog/_search_form.html.erb](hyrax-webapp/app/views/catalog/_search_form.html.erb)**

---

## 7. How to Add Catalog Navigation Customizations

### For WVU Home Theme:
1. Create `app/views/themes/wvu_home/_masthead.html.erb` (currently doesn't exist, uses default)
2. Create `app/views/themes/wvu_home/_controls.html.erb` ✓ (already exists)
3. Theme-aware CSS classes already applied in layout

### For Other Themes:
1. Create `hyrax-webapp/app/views/themes/[theme_name]/_masthead.html.erb`
2. Create `hyrax-webapp/app/views/themes/[theme_name]/_controls.html.erb`
3. Create `hyrax-webapp/app/views/themes/[theme_name]/catalog/_search_form.html.erb`

### Key Implementation Notes:
- Catalog pages use the standard `hyrax.html.erb` layout, not a catalog-specific layout
- Navigation customization happens through partial overrides, not layout selection
- Theme detection uses `home_page_theme` helper but is applied globally via static view paths
- The `admin_host?` helper determines whether to show admin or user util links

---

## Summary

**Catalog/Search Pages Navigation Rendering Flow:**

```
CatalogController request
    ↓
Uses default layout: hyrax.html.erb (not theme-specific)
    ↓
Layout calls: <%= render '/masthead', placement_class: nil %>
    ↓
View path resolution (in order):
  1. wvu_knapsack/app/views/themes/[theme]/_masthead.html.erb
  2. wvu_knapsack/app/views/_masthead.html.erb
  3. hyrax-webapp/app/views/themes/[theme]/_masthead.html.erb
  4. hyrax-webapp/app/views/_masthead.html.erb (fallback)
    ↓
Masthead renders: <%= render '/user_util_links' %> or <%= render '/admin_util_links' %>
    ↓
Additional secondary nav via: <%= render '/controls' %> (theme-specific if exists)
```

**Key Differences from Homepage Navigation:**
- Catalog pages DON'T use `inject_theme_views` around_action (only home/show pages do)
- Catalog pages rely on global static view path prepending
- Theme selection for catalog is implicit (not via `home_page_theme` or `show_page_theme`)
- Both knapsack and hyrax-webapp themes can provide overrides at the same level
