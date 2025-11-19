import Wikis from '~/wikis/wikis';
import { mountApplications } from '~/wikis/edit';
import { mountWikiSidebar } from '~/wikis/show';
import { mountMoreActions } from '~/wikis/more_actions';

mountApplications();
mountWikiSidebar();
mountMoreActions();

export default new Wikis();
