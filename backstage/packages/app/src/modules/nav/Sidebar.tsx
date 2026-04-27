import {
  Sidebar,
  SidebarDivider,
  SidebarGroup,
  SidebarItem,
  SidebarScrollWrapper,
  SidebarSpace,
} from '@backstage/core-components';
import { NavContentBlueprint } from '@backstage/plugin-app-react';
import { SidebarLogo } from './SidebarLogo';
import MenuIcon from '@material-ui/icons/Menu';
import SearchIcon from '@material-ui/icons/Search';
import { SidebarSearchModal } from '@backstage/plugin-search';
import { UserSettingsSignInAvatar } from '@backstage/plugin-user-settings';
import { NotificationsSidebarItem } from '@backstage/plugin-notifications';

function NavItem({ item }: { item: any }) {
  return (
    <SidebarItem icon={() => item.icon} to={item.href} text={item.title} />
  );
}

export const SidebarContent = NavContentBlueprint.make({
  params: {
    component: ({ navItems }) => {
      navItems.take('page:search'); // skip - using search modal instead
      const catalogItem = navItems.take('page:catalog');
      const scaffolderItem = navItems.take('page:scaffolder');
      const appVisualizerItem = navItems.take('page:app-visualizer');
      const userSettingsItem = navItems.take('page:user-settings');
      const restItems = navItems.rest().slice().sort((a: any, b: any) => a.title.localeCompare(b.title));

      return (
        <Sidebar>
          <SidebarLogo />
          <SidebarGroup label="Search" icon={<SearchIcon />} to="/search">
            <SidebarSearchModal />
          </SidebarGroup>
          <SidebarDivider />
          <SidebarGroup label="Menu" icon={<MenuIcon />}>
            {catalogItem && <NavItem key={catalogItem.node.spec.id} item={catalogItem} />}
            {scaffolderItem && <NavItem key={scaffolderItem.node.spec.id} item={scaffolderItem} />}
            <SidebarDivider />
            <SidebarScrollWrapper>
              {restItems.map((item: any) => (
                <NavItem key={item.node.spec.id} item={item} />
              ))}
            </SidebarScrollWrapper>
          </SidebarGroup>
          <SidebarSpace />
          <SidebarDivider />
          <NotificationsSidebarItem />
          <SidebarDivider />
          <SidebarGroup
            label="Settings"
            icon={<UserSettingsSignInAvatar />}
            to="/settings"
          >
            {appVisualizerItem && <NavItem key={appVisualizerItem.node.spec.id} item={appVisualizerItem} />}
            {userSettingsItem && <NavItem key={userSettingsItem.node.spec.id} item={userSettingsItem} />}
          </SidebarGroup>
        </Sidebar>
      );
    },
  },
});
